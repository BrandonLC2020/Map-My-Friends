"""Regenerate airports_export.json from the public OurAirports dataset.

Writes a committed JSON artifact; no database is involved. Existing IDs are
preserved by IATA code so that `preferred_airport_id` references stored in
Firestore stay valid across regenerations.
"""

import csv
import io
import json
import urllib.request
from pathlib import Path

from django.core.management.base import BaseCommand

OURAIRPORTS_CSV_URL = (
    "https://raw.githubusercontent.com/davidmegginson/ourairports-data/main/airports.csv"
)

ALLOWED_TYPES = {"large_airport", "medium_airport"}

OUTPUT_PATH = Path(__file__).resolve().parents[4] / "airports_export.json"


class Command(BaseCommand):
    help = "Regenerate airports_export.json from OurAirports CSV data."

    def handle(self, *args, **options):
        existing_ids: dict[str, int] = {}
        if OUTPUT_PATH.exists():
            with OUTPUT_PATH.open(encoding="utf-8") as handle:
                for row in json.load(handle):
                    if "id" in row and "iata" in row:
                        existing_ids[row["iata"]] = int(row["id"])

        self.stdout.write("Downloading airport data from OurAirports...")
        with urllib.request.urlopen(OURAIRPORTS_CSV_URL, timeout=120) as response:
            data = response.read().decode("utf-8")

        rows = []
        seen: set[str] = set()
        for row in csv.DictReader(io.StringIO(data)):
            if row.get("type", "") not in ALLOWED_TYPES:
                continue
            iata = (row.get("iata_code") or "").strip()
            if not iata or iata in seen:
                continue
            seen.add(iata)

            try:
                lat = float(row["latitude_deg"])
                lon = float(row["longitude_deg"])
            except (ValueError, KeyError):
                continue

            ident = (row.get("ident") or "")[:4]
            rows.append(
                {
                    "name": row.get("name", ""),
                    "iata": iata,
                    "icao": ident,
                    "type": row["type"],
                    "city": row.get("municipality", ""),
                    "country": row.get("iso_country", ""),
                    "continent": row.get("continent", ""),
                    "lat": lat,
                    "lon": lon,
                }
            )

        # Assign IDs: preserve known IATA codes, append new ones after the max.
        next_id = max(existing_ids.values(), default=0) + 1
        rows.sort(key=lambda r: r["iata"])
        for row in rows:
            if row["iata"] in existing_ids:
                row["id"] = existing_ids[row["iata"]]
            else:
                row["id"] = next_id
                next_id += 1

        rows.sort(key=lambda r: r["id"])
        with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=1)
            handle.write("\n")

        self.stdout.write(self.style.SUCCESS(f"Wrote {len(rows)} airports to {OUTPUT_PATH}"))
