"""Regenerate stations_export.json from the public Overpass (OSM) API.

Scope is US rail, matching the previous importer: `country` defaulted to USA,
US-specific major-station names, and US commuter networks. Overpass rate-limits
and times out on large areas, so the query is chunked by state.
"""

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from django.core.management.base import BaseCommand

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Overpass enforces its usage policy by rejecting anonymous clients with
# "406 Not Acceptable" — a misleading status that looks like content
# negotiation. urllib's default "Python-urllib/3.x" agent is blocked, and so
# is "Accept: */*". A descriptive User-Agent plus an explicit JSON Accept is
# required for every request.
REQUEST_HEADERS = {
    "User-Agent": "map-my-friends/1.0 (station dataset fetch; +https://github.com/b1codes)",
    "Accept": "application/json",
}

OUTPUT_PATH = Path(__file__).resolve().parents[4] / "stations_export.json"

# Chunked to stay under Overpass timeouts. ISO 3166-2 subdivisions.
US_STATES = [
    "US-AL",
    "US-AK",
    "US-AZ",
    "US-AR",
    "US-CA",
    "US-CO",
    "US-CT",
    "US-DE",
    "US-DC",
    "US-FL",
    "US-GA",
    "US-HI",
    "US-ID",
    "US-IL",
    "US-IN",
    "US-IA",
    "US-KS",
    "US-KY",
    "US-LA",
    "US-ME",
    "US-MD",
    "US-MA",
    "US-MI",
    "US-MN",
    "US-MS",
    "US-MO",
    "US-MT",
    "US-NE",
    "US-NV",
    "US-NH",
    "US-NJ",
    "US-NM",
    "US-NY",
    "US-NC",
    "US-ND",
    "US-OH",
    "US-OK",
    "US-OR",
    "US-PA",
    "US-RI",
    "US-SC",
    "US-SD",
    "US-TN",
    "US-TX",
    "US-UT",
    "US-VT",
    "US-VA",
    "US-WA",
    "US-WV",
    "US-WI",
    "US-WY",
]

MAJOR_NAMES = {
    "New York Penn Station",
    "Washington Union Station",
    "Boston South Station",
    "Philadelphia 30th Street Station",
    "Baltimore Penn Station",
    "Chicago Union Station",
    "St. Louis Gateway Center",
    "Kansas City Union Station",
    "Denver Union Station",
    "Salt Lake City Central Station",
    "Seattle King Street Station",
    "Portland Union Station",
    "Los Angeles Union Station",
    "Atlanta Peachtree Station",
    "New Orleans Union Passenger Terminal",
    "Miami Central Station",
    "Dallas Union Station",
    "Houston Amtrak Station",
    "Charlotte Amtrak Station",
    "St. Paul Union Depot",
    "Milwaukee Intermodal Station",
    "Detroit Amtrak Station",
    "Cleveland Amtrak Station",
    "Indianapolis Union Station",
    "Albuquerque Alvarado Center",
    "Flagstaff Amtrak Station",
    "San Diego Santa Fe Depot",
    "San Jose Diridon Station",
    "Sacramento Valley Station",
    "Stamford Station",
    "New Haven Union Station",
    "Providence Station",
    "Newark Penn Station",
    "Orlando Amtrak Station",
    "Richmond Staples Mill Road",
    "Raleigh Union Station",
    "Pittsburgh Union Station",
    "Cincinnati Union Terminal",
    "Vancouver Amtrak Station",
    "Oakland Jack London Square",
    "Union Station",
    "South Station",
    "Penn Station",
}

COMMUTER_NETWORKS = (
    "LIRR",
    "Metro-North",
    "NJ Transit",
    "MBTA",
    "Caltrain",
    "Metra",
    "SEPTA",
    "Metrolink",
)


def classify(name: str, tags: dict) -> str:
    """Station type, matching the previous importer's precedence exactly."""
    operator = tags.get("operator", "")
    network = tags.get("network", "")

    is_amtrak = (
        "Amtrak" in name
        or "Amtrak" in operator
        or "Amtrak" in network
        or "amtrak:code" in tags
    )
    if name in MAJOR_NAMES or is_amtrak or "uic_ref" in tags:
        return "major_station"

    if (
        "Subway" in name
        or "Metro" in name
        or "BART" in name
        or "Path Station" in name
        or tags.get("railway") == "subway"
        or tags.get("station") == "subway"
    ):
        return "subway_station"

    if (
        any(net in network for net in COMMUTER_NETWORKS)
        or "commuter" in tags.get("railway", "")
        or "commuter" in network.lower()
    ):
        return "commuter_rail_station"

    return "regional_station"


class Command(BaseCommand):
    help = "Regenerate stations_export.json from the Overpass API."

    def add_arguments(self, parser):
        parser.add_argument(
            "--sleep",
            type=float,
            default=5.0,
            help="Seconds to wait between state queries (Overpass is rate-limited).",
        )
        parser.add_argument(
            "--retries",
            type=int,
            default=3,
            help="Attempts per state before giving up (429/504 are common).",
        )
        parser.add_argument(
            "--states",
            nargs="+",
            metavar="ISO",
            help=(
                "Only fetch these ISO 3166-2 subdivisions (e.g. US-OR US-RI). "
                "Results merge into the existing dataset, so this fills gaps "
                "left by failed states without refetching everything."
            ),
        )

    def handle(self, *args, **options):
        # Load the whole existing dataset, not just its IDs: a state that fails
        # every retry must keep the records from a previous run rather than
        # silently vanishing from the output.
        collected: dict[int, dict] = {}
        existing_ids: dict[int, int] = {}
        if OUTPUT_PATH.exists():
            with OUTPUT_PATH.open(encoding="utf-8") as handle:
                for row in json.load(handle):
                    osm_id = int(row["osm_id"])
                    existing_ids[osm_id] = int(row["id"])
                    collected[osm_id] = {k: v for k, v in row.items() if k != "id"}
            self.stdout.write(f"Loaded {len(collected)} existing stations.")

        states = options["states"] or US_STATES
        failed: list[str] = []

        for state in states:
            query = f"""
            [out:json][timeout:180];
            area["ISO3166-2"="{state}"][admin_level=4]->.a;
            (
              node["railway"="station"](area.a);
              node["railway"="halt"](area.a);
            );
            out body;
            """
            self.stdout.write(f"Querying {state}...")
            payload = None
            for attempt in range(options["retries"]):
                try:
                    request = urllib.request.Request(
                        OVERPASS_URL,
                        data=urllib.parse.urlencode({"data": query}).encode(),
                        headers=REQUEST_HEADERS,
                    )
                    with urllib.request.urlopen(request, timeout=300) as response:
                        payload = json.load(response)
                    break
                except (
                    urllib.error.URLError,
                    TimeoutError,
                    json.JSONDecodeError,
                ) as exc:
                    if attempt < options["retries"] - 1:
                        # 429 and 504 are the usual failures and both ease off
                        # with time, so back off exponentially before retrying.
                        backoff = options["sleep"] * (2 ** (attempt + 1))
                        self.stderr.write(
                            f"  {state} attempt {attempt + 1} failed ({exc}); "
                            f"retrying in {backoff:.0f}s."
                        )
                        time.sleep(backoff)
                    else:
                        self.stderr.write(
                            f"  {state} failed after {options['retries']} attempts "
                            f"({exc}); keeping any existing records."
                        )
                        failed.append(state)

            if payload is None:
                time.sleep(options["sleep"])
                continue

            for element in payload.get("elements", []):
                if element.get("type") != "node":
                    continue
                tags = element.get("tags", {})
                name = tags.get("name")
                osm_id = element.get("id")
                lat = element.get("lat")
                lon = element.get("lon")
                if not name or osm_id is None or lat is None or lon is None:
                    continue

                collected[int(osm_id)] = {
                    "name": name,
                    "osm_id": int(osm_id),
                    "station_type": classify(name, tags),
                    "uic_ref": tags.get("uic_ref", tags.get("amtrak:code", "")),
                    "city": tags.get("addr:city", ""),
                    "country": tags.get("addr:country", "USA"),
                    "lat": float(lat),
                    "lon": float(lon),
                }

            self.stdout.write(f"  running total: {len(collected)}")
            time.sleep(options["sleep"])

        rows = sorted(collected.values(), key=lambda r: r["osm_id"])
        next_id = max(existing_ids.values(), default=0) + 1
        for row in rows:
            if row["osm_id"] in existing_ids:
                row["id"] = existing_ids[row["osm_id"]]
            else:
                row["id"] = next_id
                next_id += 1

        rows.sort(key=lambda r: r["id"])
        # Write via a temp file and atomic rename so an interrupted run cannot
        # leave a truncated dataset behind.
        tmp_path = OUTPUT_PATH.with_suffix(".json.tmp")
        with tmp_path.open("w", encoding="utf-8") as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        tmp_path.replace(OUTPUT_PATH)

        self.stdout.write(
            self.style.SUCCESS(f"Wrote {len(rows)} stations to {OUTPUT_PATH}")
        )
        if failed:
            self.stdout.write(
                self.style.WARNING(
                    f"{len(failed)} state(s) failed: {' '.join(failed)}\n"
                    f"Re-run just those with: "
                    f"manage.py fetch_stations --states {' '.join(failed)}"
                )
            )
