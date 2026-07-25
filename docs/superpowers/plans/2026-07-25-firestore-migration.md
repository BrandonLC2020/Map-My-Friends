# Firestore + Emulator Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the local PostgreSQL/PostGIS database with Google Cloud Firestore backed by the Firebase Emulator Suite, moving static airport/station data to an in-memory index.

**Architecture:** User-owned data (Person, ContactLog, Trip, TripStop, TripLeg, UserProfile) moves behind an explicit repository layer talking to Firestore via `firebase-admin`. Static reference data (airports, stations) becomes committed JSON loaded into an in-memory Haversine index — no database at all. Django's own `auth`/`admin`/`sessions`/`contenttypes` tables move to SQLite, since Auth0 still JIT-provisions `User` rows until the sibling GCIP task lands.

**Tech Stack:** Django 6.0, DRF 3.16, `firebase-admin`, Firebase Emulator Suite, SQLite, Flutter (2-line change only).

**Spec:** `docs/superpowers/specs/2026-07-25-firestore-migration-design.md`
**ClickUp:** [86bb077ur](https://app.clickup.com/t/86bb077ur)

## Global Constraints

- **All 395 lines of `backend/tests/test_api_security.py` must pass with assertions unchanged.** They encode ownership isolation from commit `e81891d`. Never weaken an assertion to make a refactor pass.
- The project uses **Django's test runner**, not pytest. Tests subclass `django.test.TestCase` or DRF's `APITestCase`. Run via `make test` → `manage.py test`.
- **No application code may branch on environment** to choose Firestore vs. emulator. `FIRESTORE_EMULATOR_HOST` is detected by `firebase-admin` itself.
- Python `>=3.12,<4.0`. Django `>=6.0.2,<7.0.0`. DRF `>=3.16.1,<4.0.0`.
- Poetry manages dependencies; commands run inside Docker via `docker compose exec api poetry run ...`.
- The GeoJSON `Feature` envelope emitted by `rest_framework_gis` **must be reproduced exactly** — `{"id":…, "type":"Feature", "geometry":{"type":"Point","coordinates":[lng,lat]}, "properties":{…}}`. Flutter's `Person.fromGeoJson` (`frontend/lib/models/person.dart:110`) depends on it, and a mismatch fails silently rather than erroring.
- Airport/Station IDs stay **integers** and must be **stable across regeneration** — `preferred_airport_id` in Firestore references them, and `frontend/lib/models/airport.dart:48` casts `as int?`.
- Commit after every task.

---

## File Structure

**New shared module — `backend/apps/common/`** (currently no shared package exists; these are used by 3+ apps):

| File | Responsibility |
|---|---|
| `apps/common/__init__.py` | package marker |
| `apps/common/geo.py` | `haversine_km()` — pure function, no Django imports |
| `apps/common/firestore.py` | lazily-initialised Firestore client singleton |
| `apps/common/serializers.py` | `GeoFeatureSerializer` — GeoJSON envelope base class |
| `apps/common/exception_handlers.py` | maps `google.api_core` errors to DRF responses |
| `apps/common/storage.py` | `save_upload()` / `upload_url()` over Django `STORAGES` |
| `apps/common/testing.py` | `FirestoreTestMixin` — purges emulator collections in `setUp` |

**Per-app additions:** `reference.py` (airports, stations), `repositories.py` (people, trips, users), `services.py` (people — geocoding).

**Deleted:** `apps/airports/models.py`, `apps/stations/models.py`, all `migrations/` for the five app models, all six `admin.py` registrations, `apps/*/management/commands/import_*.py` (replaced by `fetch_*.py`).

---

## Phase 1 — Reference data off PostGIS

*Independently shippable: after Phase 1 the app still runs, with airports and stations served from memory while user data remains on PostGIS.*

### Task 1: Shared Haversine helper

**Files:**
- Create: `backend/apps/common/__init__.py`
- Create: `backend/apps/common/geo.py`
- Test: `backend/apps/common/tests/__init__.py`, `backend/apps/common/tests/test_geo.py`

**Interfaces:**
- Consumes: nothing
- Produces: `haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float` — great-circle distance in kilometres

- [ ] **Step 1: Write the failing test**

Create `backend/apps/common/tests/__init__.py` (empty) and `backend/apps/common/tests/test_geo.py`:

```python
from django.test import SimpleTestCase

from apps.common.geo import haversine_km


class HaversineTests(SimpleTestCase):
    def test_zero_distance(self):
        self.assertAlmostEqual(haversine_km(41.8781, -87.6298, 41.8781, -87.6298), 0.0, places=6)

    def test_known_distance_chicago_to_midway(self):
        # Downtown Chicago -> Midway International is roughly 14-16 km.
        km = haversine_km(41.8781, -87.6298, 41.7868, -87.7524)
        self.assertGreater(km, 10)
        self.assertLess(km, 20)

    def test_known_distance_chicago_to_jfk(self):
        # Downtown Chicago -> JFK is roughly 1150 km.
        km = haversine_km(41.8781, -87.6298, 40.6413, -73.7781)
        self.assertGreater(km, 1100)
        self.assertLess(km, 1200)

    def test_symmetric(self):
        a = haversine_km(41.8781, -87.6298, 40.6413, -73.7781)
        b = haversine_km(40.6413, -73.7781, 41.8781, -87.6298)
        self.assertAlmostEqual(a, b, places=9)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_geo -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/common/__init__.py` (empty file), then `backend/apps/common/geo.py`:

```python
"""Pure geodesic helpers. Deliberately free of Django imports so the
reference indexes can be unit-tested without database or settings setup."""

from __future__ import annotations

import math

# Mean Earth radius (WGS-84 authalic), kilometres.
EARTH_RADIUS_KM = 6371.0088


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance between two WGS-84 points, in kilometres."""
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)

    a = (
        math.sin(d_phi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_geo -v 2`
Expected: PASS — 4 tests

- [ ] **Step 5: Commit**

```bash
git add backend/apps/common/
git commit -m "feat(common): add Haversine distance helper for in-memory geo search"
```

---

### Task 2: Airport reference index

**Files:**
- Create: `backend/apps/airports/reference.py`
- Test: `backend/apps/airports/tests.py` (replace entirely)

**Interfaces:**
- Consumes: `apps.common.geo.haversine_km`
- Produces:
  - `Airport` frozen dataclass with fields `id: int`, `name: str`, `iata_code: str`, `icao_code: str`, `airport_type: str`, `city: str`, `country: str`, `continent: str`, `lat: float`, `lng: float`, and attribute `distance_km: float | None`
  - `all_airports() -> list[Airport]`
  - `get_by_id(airport_id: int) -> Airport | None`
  - `get_nearby(lat: float, lng: float, radius_km: float | None = None, count: int = 10) -> list[Airport]` — returns copies carrying `distance_km`, sorted ascending

- [ ] **Step 1: Write the failing test**

Replace `backend/apps/airports/tests.py` entirely:

```python
from django.test import SimpleTestCase

from apps.airports import reference


class AirportReferenceTests(SimpleTestCase):
    """Exercises the in-memory index against the committed dataset."""

    def test_dataset_loads(self):
        airports = reference.all_airports()
        self.assertGreater(len(airports), 4000)

    def test_ids_are_unique_integers(self):
        ids = [a.id for a in reference.all_airports()]
        self.assertTrue(all(isinstance(i, int) for i in ids))
        self.assertEqual(len(ids), len(set(ids)))

    def test_get_by_id_round_trips(self):
        first = reference.all_airports()[0]
        self.assertEqual(reference.get_by_id(first.id), first)

    def test_get_by_id_missing_returns_none(self):
        self.assertIsNone(reference.get_by_id(-1))

    def test_get_nearby_sorting(self):
        # Downtown Chicago: Midway is closer than O'Hare.
        nearby = reference.get_nearby(41.8781, -87.6298, count=10)
        codes = [a.iata_code for a in nearby]
        self.assertIn("MDW", codes)
        self.assertIn("ORD", codes)
        self.assertLess(codes.index("MDW"), codes.index("ORD"))

    def test_get_nearby_respects_count(self):
        self.assertEqual(len(reference.get_nearby(41.8781, -87.6298, count=3)), 3)

    def test_get_nearby_radius_filter(self):
        within_20 = reference.get_nearby(41.8781, -87.6298, radius_km=20, count=10)
        codes = [a.iata_code for a in within_20]
        self.assertIn("MDW", codes)
        self.assertNotIn("JFK", codes)

    def test_distance_km_populated_and_ascending(self):
        nearby = reference.get_nearby(41.8781, -87.6298, count=5)
        distances = [a.distance_km for a in nearby]
        self.assertTrue(all(d is not None for d in distances))
        self.assertEqual(distances, sorted(distances))

    def test_distance_km_plausible(self):
        nearest = reference.get_nearby(41.8781, -87.6298, count=1)[0]
        self.assertGreater(nearest.distance_km, 0)
        self.assertLess(nearest.distance_km, 40)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.airports -v 2`
Expected: FAIL — `ImportError: cannot import name 'reference' from 'apps.airports'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/airports/reference.py`:

```python
"""In-memory airport index.

Replaces the PostGIS-backed Airport model. The dataset is static (~4,500
records, regenerated only when `fetch_airports` is run), so a linear
Haversine sweep is both simpler and faster than a database round trip.
"""

from __future__ import annotations

import dataclasses
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from apps.common.geo import haversine_km

DATA_FILE = Path(__file__).resolve().parent.parent.parent / "airports_export.json"


@dataclass(frozen=True)
class Airport:
    id: int
    name: str
    iata_code: str
    icao_code: str
    airport_type: str
    city: str
    country: str
    continent: str
    lat: float
    lng: float
    distance_km: float | None = None


@lru_cache(maxsize=1)
def _load() -> tuple[tuple[Airport, ...], dict[int, Airport]]:
    with DATA_FILE.open(encoding="utf-8") as handle:
        raw = json.load(handle)

    airports = tuple(
        Airport(
            id=int(row["id"]),
            name=row.get("name", ""),
            iata_code=row.get("iata", ""),
            icao_code=row.get("icao", "") or "",
            airport_type=row.get("type", ""),
            city=row.get("city", "") or "",
            country=row.get("country", "") or "",
            continent=row.get("continent", "") or "",
            lat=float(row["lat"]),
            lng=float(row["lon"]),
        )
        for row in raw
    )
    return airports, {a.id: a for a in airports}


def all_airports() -> list[Airport]:
    return list(_load()[0])


def get_by_id(airport_id: int) -> Airport | None:
    return _load()[1].get(airport_id)


def get_nearby(
    lat: float,
    lng: float,
    radius_km: float | None = None,
    count: int = 10,
) -> list[Airport]:
    """Airports ordered by distance from (lat, lng), nearest first.

    Returns copies carrying a populated `distance_km`; the cached originals
    are never mutated.
    """
    scored: list[tuple[float, Airport]] = []
    for airport in _load()[0]:
        km = haversine_km(lat, lng, airport.lat, airport.lng)
        if radius_km is not None and km > radius_km:
            continue
        scored.append((km, airport))

    scored.sort(key=lambda pair: pair[0])
    return [
        dataclasses.replace(airport, distance_km=round(km, 1))
        for km, airport in scored[:count]
    ]
```

- [ ] **Step 4: Run test to verify it fails on missing `id`**

Run: `docker compose exec api poetry run python manage.py test apps.airports -v 2`
Expected: FAIL — `KeyError: 'id'`. The committed `airports_export.json` has no `id`, `icao`, or `continent` keys yet; Task 3 regenerates it. This failure is expected and confirms the loader reads the real file.

- [ ] **Step 5: Commit**

```bash
git add backend/apps/airports/reference.py backend/apps/airports/tests.py
git commit -m "feat(airports): add in-memory reference index (dataset regen pending)"
```

---

### Task 3: Regenerate the airports dataset

**Files:**
- Create: `backend/apps/airports/management/commands/fetch_airports.py`
- Delete: `backend/apps/airports/management/commands/import_airports.py`
- Modify: `backend/airports_export.json` (regenerated)

**Interfaces:**
- Consumes: nothing
- Produces: `airports_export.json` records shaped `{id, name, iata, icao, type, city, country, continent, lat, lon}` — consumed by `apps.airports.reference`

- [ ] **Step 1: Write the fetch command**

Create `backend/apps/airports/management/commands/fetch_airports.py`:

```python
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
```

- [ ] **Step 2: Run the command to regenerate the dataset**

Run: `docker compose exec api poetry run python manage.py fetch_airports`
Expected: `Wrote 4XXX airports to /app/airports_export.json` (count near 4,551; it tracks upstream OurAirports data)

- [ ] **Step 3: Run the Task 2 tests to verify they now pass**

Run: `docker compose exec api poetry run python manage.py test apps.airports -v 2`
Expected: PASS — 9 tests

- [ ] **Step 4: Delete the obsolete importer**

```bash
git rm backend/apps/airports/management/commands/import_airports.py
```

- [ ] **Step 5: Commit**

```bash
git add backend/apps/airports/management/commands/fetch_airports.py backend/airports_export.json
git commit -m "feat(airports): regenerate dataset with stable IDs, replace DB importer with fetch"
```

---

### Task 4: Station dataset fetch

**Files:**
- Create: `backend/apps/stations/management/commands/fetch_stations.py`
- Create: `backend/stations_export.json` (generated)
- Delete: `backend/apps/stations/management/commands/import_stations.py`

**Interfaces:**
- Consumes: nothing
- Produces: `stations_export.json` records shaped `{id, name, osm_id, station_type, uic_ref, city, country, lat, lon}`

- [ ] **Step 1: Write the fetch command**

Create `backend/apps/stations/management/commands/fetch_stations.py`. The categorisation logic is carried over verbatim from the deleted `import_stations.py` so station types stay identical:

```python
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

OUTPUT_PATH = Path(__file__).resolve().parents[4] / "stations_export.json"

# Chunked to stay under Overpass timeouts. ISO 3166-2 subdivisions.
US_STATES = [
    "US-AL", "US-AK", "US-AZ", "US-AR", "US-CA", "US-CO", "US-CT", "US-DE",
    "US-DC", "US-FL", "US-GA", "US-HI", "US-ID", "US-IL", "US-IN", "US-IA",
    "US-KS", "US-KY", "US-LA", "US-ME", "US-MD", "US-MA", "US-MI", "US-MN",
    "US-MS", "US-MO", "US-MT", "US-NE", "US-NV", "US-NH", "US-NJ", "US-NM",
    "US-NY", "US-NC", "US-ND", "US-OH", "US-OK", "US-OR", "US-PA", "US-RI",
    "US-SC", "US-SD", "US-TN", "US-TX", "US-UT", "US-VT", "US-VA", "US-WA",
    "US-WV", "US-WI", "US-WY",
]

MAJOR_NAMES = {
    "New York Penn Station", "Washington Union Station", "Boston South Station",
    "Philadelphia 30th Street Station", "Baltimore Penn Station", "Chicago Union Station",
    "St. Louis Gateway Center", "Kansas City Union Station", "Denver Union Station",
    "Salt Lake City Central Station", "Seattle King Street Station", "Portland Union Station",
    "Los Angeles Union Station", "Atlanta Peachtree Station", "New Orleans Union Passenger Terminal",
    "Miami Central Station", "Dallas Union Station", "Houston Amtrak Station",
    "Charlotte Amtrak Station", "St. Paul Union Depot", "Milwaukee Intermodal Station",
    "Detroit Amtrak Station", "Cleveland Amtrak Station", "Indianapolis Union Station",
    "Albuquerque Alvarado Center", "Flagstaff Amtrak Station", "San Diego Santa Fe Depot",
    "San Jose Diridon Station", "Sacramento Valley Station", "Stamford Station",
    "New Haven Union Station", "Providence Station", "Newark Penn Station",
    "Orlando Amtrak Station", "Richmond Staples Mill Road", "Raleigh Union Station",
    "Pittsburgh Union Station", "Cincinnati Union Terminal", "Vancouver Amtrak Station",
    "Oakland Jack London Square", "Union Station", "South Station", "Penn Station",
}

COMMUTER_NETWORKS = (
    "LIRR", "Metro-North", "NJ Transit", "MBTA", "Caltrain", "Metra",
    "SEPTA", "Metrolink",
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
            default=3.0,
            help="Seconds to wait between state queries (Overpass is rate-limited).",
        )

    def handle(self, *args, **options):
        existing_ids: dict[int, int] = {}
        if OUTPUT_PATH.exists():
            with OUTPUT_PATH.open(encoding="utf-8") as handle:
                for row in json.load(handle):
                    existing_ids[int(row["osm_id"])] = int(row["id"])

        collected: dict[int, dict] = {}

        for state in US_STATES:
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
            try:
                request = urllib.request.Request(
                    OVERPASS_URL,
                    data=urllib.parse.urlencode({"data": query}).encode(),
                )
                with urllib.request.urlopen(request, timeout=300) as response:
                    payload = json.load(response)
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                self.stderr.write(f"  {state} failed ({exc}); skipping.")
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
        with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=1)
            handle.write("\n")

        self.stdout.write(self.style.SUCCESS(f"Wrote {len(rows)} stations to {OUTPUT_PATH}"))
```

- [ ] **Step 2: Run the command to generate the dataset**

Run: `docker compose exec api poetry run python manage.py fetch_stations`
Expected: per-state progress lines, ending `Wrote NNNNN stations to /app/stations_export.json`. Takes several minutes due to deliberate rate-limit sleeps. Individual states may fail and be skipped — acceptable, rerun to fill gaps.

- [ ] **Step 3: Sanity-check the output**

Run:
```bash
docker compose exec api poetry run python -c "
import json
rows = json.load(open('stations_export.json'))
print('count:', len(rows))
print('unique ids:', len({r['id'] for r in rows}))
print('types:', {r['station_type'] for r in rows})
print('sample:', rows[0])
"
```
Expected: count in the thousands, `unique ids` equal to count, and `types` a subset of `{major_station, regional_station, subway_station, commuter_rail_station}`.

- [ ] **Step 4: Delete the obsolete importer**

```bash
git rm backend/apps/stations/management/commands/import_stations.py
```

- [ ] **Step 5: Commit**

```bash
git add backend/apps/stations/management/commands/fetch_stations.py backend/stations_export.json
git commit -m "feat(stations): fetch US rail data from Overpass into committed dataset"
```

---

### Task 5: Station reference index

**Files:**
- Create: `backend/apps/stations/reference.py`
- Test: `backend/apps/stations/tests.py` (replace entirely)

**Interfaces:**
- Consumes: `apps.common.geo.haversine_km`
- Produces:
  - `Station` frozen dataclass — `id: int`, `name: str`, `osm_id: int`, `station_type: str`, `uic_ref: str`, `city: str`, `country: str`, `lat: float`, `lng: float`, `distance_km: float | None`
  - `all_stations() -> list[Station]`
  - `get_by_id(station_id: int) -> Station | None`
  - `get_nearby(lat, lng, radius_km=None, count=10, station_type=None) -> list[Station]`

Note the extra `station_type` parameter — `apps/stations/views.py:47` filters on it, which the airport equivalent does not do.

- [ ] **Step 1: Write the failing test**

Replace `backend/apps/stations/tests.py` entirely:

```python
from django.test import SimpleTestCase

from apps.stations import reference


class StationReferenceTests(SimpleTestCase):
    def test_dataset_loads(self):
        self.assertGreater(len(reference.all_stations()), 100)

    def test_ids_are_unique_integers(self):
        ids = [s.id for s in reference.all_stations()]
        self.assertTrue(all(isinstance(i, int) for i in ids))
        self.assertEqual(len(ids), len(set(ids)))

    def test_get_by_id_round_trips(self):
        first = reference.all_stations()[0]
        self.assertEqual(reference.get_by_id(first.id), first)

    def test_get_by_id_missing_returns_none(self):
        self.assertIsNone(reference.get_by_id(-1))

    def test_get_nearby_respects_count(self):
        self.assertEqual(len(reference.get_nearby(41.8781, -87.6298, count=3)), 3)

    def test_get_nearby_sorted_ascending(self):
        distances = [s.distance_km for s in reference.get_nearby(41.8781, -87.6298, count=5)]
        self.assertTrue(all(d is not None for d in distances))
        self.assertEqual(distances, sorted(distances))

    def test_get_nearby_radius_filter(self):
        near = reference.get_nearby(41.8781, -87.6298, radius_km=25, count=10)
        self.assertTrue(all(s.distance_km <= 25 for s in near))

    def test_station_type_filter(self):
        filtered = reference.get_nearby(
            41.8781, -87.6298, count=10, station_type="major_station"
        )
        self.assertTrue(all(s.station_type == "major_station" for s in filtered))

    def test_unknown_station_type_returns_empty(self):
        self.assertEqual(
            reference.get_nearby(41.8781, -87.6298, station_type="not_a_type"), []
        )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.stations -v 2`
Expected: FAIL — `ImportError: cannot import name 'reference' from 'apps.stations'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/stations/reference.py`:

```python
"""In-memory station index. Mirrors apps.airports.reference, with the
additional station_type filter that the nearest-stations endpoint exposes."""

from __future__ import annotations

import dataclasses
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from apps.common.geo import haversine_km

DATA_FILE = Path(__file__).resolve().parent.parent.parent / "stations_export.json"


@dataclass(frozen=True)
class Station:
    id: int
    name: str
    osm_id: int
    station_type: str
    uic_ref: str
    city: str
    country: str
    lat: float
    lng: float
    distance_km: float | None = None


@lru_cache(maxsize=1)
def _load() -> tuple[tuple[Station, ...], dict[int, Station]]:
    with DATA_FILE.open(encoding="utf-8") as handle:
        raw = json.load(handle)

    stations = tuple(
        Station(
            id=int(row["id"]),
            name=row.get("name", ""),
            osm_id=int(row["osm_id"]),
            station_type=row.get("station_type", "regional_station"),
            uic_ref=row.get("uic_ref", "") or "",
            city=row.get("city", "") or "",
            country=row.get("country", "") or "",
            lat=float(row["lat"]),
            lng=float(row["lon"]),
        )
        for row in raw
    )
    return stations, {s.id: s for s in stations}


def all_stations() -> list[Station]:
    return list(_load()[0])


def get_by_id(station_id: int) -> Station | None:
    return _load()[1].get(station_id)


def get_nearby(
    lat: float,
    lng: float,
    radius_km: float | None = None,
    count: int = 10,
    station_type: str | None = None,
) -> list[Station]:
    scored: list[tuple[float, Station]] = []
    for station in _load()[0]:
        if station_type is not None and station.station_type != station_type:
            continue
        km = haversine_km(lat, lng, station.lat, station.lng)
        if radius_km is not None and km > radius_km:
            continue
        scored.append((km, station))

    scored.sort(key=lambda pair: pair[0])
    return [
        dataclasses.replace(station, distance_km=round(km, 1))
        for km, station in scored[:count]
    ]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.stations -v 2`
Expected: PASS — 9 tests

- [ ] **Step 5: Commit**

```bash
git add backend/apps/stations/reference.py backend/apps/stations/tests.py
git commit -m "feat(stations): add in-memory reference index with type filtering"
```

---

### Task 6: GeoJSON envelope serializer base

**Files:**
- Create: `backend/apps/common/serializers.py`
- Test: `backend/apps/common/tests/test_serializers.py`

**Interfaces:**
- Consumes: nothing
- Produces: `GeoFeatureSerializer` — a `rest_framework.serializers.Serializer` subclass emitting the GeoJSON Feature envelope. Subclasses declare `lat` and `lng` fields plus an `id` field; the base moves them out of `properties`.

- [ ] **Step 1: Write the failing test**

Create `backend/apps/common/tests/test_serializers.py`:

```python
from django.test import SimpleTestCase
from rest_framework import serializers

from apps.common.serializers import GeoFeatureSerializer


class _Thing:
    def __init__(self, id, name, lat, lng):
        self.id = id
        self.name = name
        self.lat = lat
        self.lng = lng


class ThingSerializer(GeoFeatureSerializer):
    id = serializers.CharField()
    name = serializers.CharField()
    lat = serializers.FloatField()
    lng = serializers.FloatField()


class GeoFeatureSerializerTests(SimpleTestCase):
    def test_emits_feature_envelope(self):
        data = ThingSerializer(_Thing("abc", "Somewhere", 41.8781, -87.6298)).data
        self.assertEqual(data["type"], "Feature")
        self.assertEqual(data["id"], "abc")

    def test_coordinates_are_lng_lat_order(self):
        data = ThingSerializer(_Thing("abc", "Somewhere", 41.8781, -87.6298)).data
        self.assertEqual(data["geometry"]["type"], "Point")
        self.assertEqual(data["geometry"]["coordinates"], [-87.6298, 41.8781])

    def test_non_geo_fields_live_in_properties(self):
        data = ThingSerializer(_Thing("abc", "Somewhere", 41.8781, -87.6298)).data
        self.assertEqual(data["properties"]["name"], "Somewhere")

    def test_id_and_coords_excluded_from_properties(self):
        data = ThingSerializer(_Thing("abc", "Somewhere", 41.8781, -87.6298)).data
        for key in ("id", "lat", "lng"):
            self.assertNotIn(key, data["properties"])

    def test_null_geometry_when_coords_missing(self):
        data = ThingSerializer(_Thing("abc", "Somewhere", None, None)).data
        self.assertIsNone(data["geometry"])

    def test_many_true_returns_list_of_features(self):
        things = [_Thing("a", "A", 1.0, 2.0), _Thing("b", "B", 3.0, 4.0)]
        data = ThingSerializer(things, many=True).data
        self.assertEqual(len(data), 2)
        self.assertTrue(all(item["type"] == "Feature" for item in data))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_serializers -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.serializers'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/common/serializers.py`:

```python
"""GeoJSON Feature envelope, replacing rest_framework_gis.

The exact output shape is load-bearing: frontend/lib/models/person.dart
parses it via Person.fromGeoJson, reading coordinates as [lng, lat]. A shape
mismatch fails silently (pins vanish) rather than raising, so this is covered
by explicit tests.
"""

from __future__ import annotations

from rest_framework import serializers


class GeoFeatureSerializer(serializers.Serializer):
    """Serializer emitting {id, type, geometry, properties}.

    Subclasses declare ordinary fields including `id`, `lat` and `lng`. Those
    three are lifted out of `properties` into the envelope.
    """

    lat_field = "lat"
    lng_field = "lng"
    id_field = "id"

    def to_representation(self, instance):
        properties = super().to_representation(instance)

        identifier = properties.pop(self.id_field, None)
        lat = properties.pop(self.lat_field, None)
        lng = properties.pop(self.lng_field, None)

        geometry = None
        if lat is not None and lng is not None:
            geometry = {"type": "Point", "coordinates": [lng, lat]}

        return {
            "id": identifier,
            "type": "Feature",
            "geometry": geometry,
            "properties": properties,
        }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_serializers -v 2`
Expected: PASS — 6 tests

- [ ] **Step 5: Commit**

```bash
git add backend/apps/common/serializers.py backend/apps/common/tests/test_serializers.py
git commit -m "feat(common): add GeoJSON Feature serializer base replacing rest_framework_gis"
```

---

### Task 7: Rewire airport & station endpoints

**Files:**
- Modify: `backend/apps/airports/serializers.py` (rewrite), `backend/apps/airports/views.py` (rewrite), `backend/apps/airports/admin.py` (empty out)
- Modify: `backend/apps/stations/serializers.py` (rewrite), `backend/apps/stations/views.py` (rewrite), `backend/apps/stations/admin.py` (empty out)
- Delete: `backend/apps/airports/models.py`, `backend/apps/stations/models.py`, and both `migrations/` directories
- Test: `backend/apps/airports/tests.py`, `backend/apps/stations/tests.py` (append endpoint tests)

**Interfaces:**
- Consumes: `apps.airports.reference.get_nearby`, `apps.stations.reference.get_nearby`, `apps.common.serializers.GeoFeatureSerializer`
- Produces: `AirportSerializer`, `StationSerializer` — used later by `apps.people.serializers` for the `preferred_*_detail` nested fields

- [ ] **Step 1: Write the failing endpoint tests**

Append to `backend/apps/airports/tests.py`:

```python
from django.contrib.auth.models import User
from rest_framework.test import APITestCase


class NearestAirportsEndpointTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="tester", password="pw12345!")
        self.client.force_authenticate(user=self.user)

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get("/api/airports/nearest/?lat=41.8781&lon=-87.6298")
        self.assertEqual(response.status_code, 401)

    def test_returns_geojson_features(self):
        response = self.client.get("/api/airports/nearest/?lat=41.8781&lon=-87.6298&count=3")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 3)
        feature = response.data[0]
        self.assertEqual(feature["type"], "Feature")
        self.assertEqual(feature["geometry"]["type"], "Point")
        self.assertIn("iata_code", feature["properties"])
        self.assertIn("distance_km", feature["properties"])

    def test_missing_params_return_400(self):
        response = self.client.get("/api/airports/nearest/")
        self.assertEqual(response.status_code, 400)

    def test_count_is_clamped_to_ten(self):
        response = self.client.get("/api/airports/nearest/?lat=41.8781&lon=-87.6298&count=99")
        self.assertEqual(len(response.data), 10)
```

Append to `backend/apps/stations/tests.py`:

```python
from django.contrib.auth.models import User
from rest_framework.test import APITestCase


class NearestStationsEndpointTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="tester", password="pw12345!")
        self.client.force_authenticate(user=self.user)

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        response = self.client.get("/api/stations/nearest/?lat=41.8781&lon=-87.6298")
        self.assertEqual(response.status_code, 401)

    def test_returns_geojson_features(self):
        response = self.client.get("/api/stations/nearest/?lat=41.8781&lon=-87.6298&count=3")
        self.assertEqual(response.status_code, 200)
        feature = response.data[0]
        self.assertEqual(feature["type"], "Feature")
        self.assertIn("osm_id", feature["properties"])

    def test_station_type_filter_applied(self):
        response = self.client.get(
            "/api/stations/nearest/?lat=41.8781&lon=-87.6298&station_type=major_station"
        )
        self.assertEqual(response.status_code, 200)
        for feature in response.data:
            self.assertEqual(feature["properties"]["station_type"], "major_station")

    def test_missing_params_return_400(self):
        response = self.client.get("/api/stations/nearest/")
        self.assertEqual(response.status_code, 400)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `docker compose exec api poetry run python manage.py test apps.airports apps.stations -v 2`
Expected: FAIL — assertion errors on the `Feature` envelope, since the current views still query the ORM.

- [ ] **Step 3: Rewrite serializers**

Replace `backend/apps/airports/serializers.py`:

```python
from rest_framework import serializers

from apps.common.serializers import GeoFeatureSerializer


class AirportSerializer(GeoFeatureSerializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True)
    iata_code = serializers.CharField(read_only=True)
    icao_code = serializers.CharField(read_only=True, allow_blank=True)
    airport_type = serializers.CharField(read_only=True)
    city = serializers.CharField(read_only=True, allow_blank=True)
    country = serializers.CharField(read_only=True, allow_blank=True)
    continent = serializers.CharField(read_only=True, allow_blank=True)
    lat = serializers.FloatField(read_only=True)
    lng = serializers.FloatField(read_only=True)
    distance_km = serializers.FloatField(read_only=True, required=False)
```

Replace `backend/apps/stations/serializers.py`:

```python
from rest_framework import serializers

from apps.common.serializers import GeoFeatureSerializer


class StationSerializer(GeoFeatureSerializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True)
    osm_id = serializers.IntegerField(read_only=True)
    station_type = serializers.CharField(read_only=True)
    uic_ref = serializers.CharField(read_only=True, allow_blank=True)
    city = serializers.CharField(read_only=True, allow_blank=True)
    country = serializers.CharField(read_only=True, allow_blank=True)
    lat = serializers.FloatField(read_only=True)
    lng = serializers.FloatField(read_only=True)
    distance_km = serializers.FloatField(read_only=True, required=False)
```

- [ ] **Step 4: Rewrite views**

Replace `backend/apps/airports/views.py`:

```python
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import reference
from .serializers import AirportSerializer


class NearestAirportsView(APIView):
    """Return the N nearest airports to a given latitude/longitude.

    Query params:
        lat (float): Latitude
        lon (float): Longitude
        count (int): Number of airports to return (default 3, max 10)
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            lat = float(request.query_params.get('lat'))
            lon = float(request.query_params.get('lon'))
        except (TypeError, ValueError):
            return Response(
                {'error': 'lat and lon query parameters are required and must be numbers.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            count = int(request.query_params.get('count', 3))
            count = min(max(count, 1), 10)  # Clamp between 1 and 10
        except (TypeError, ValueError):
            count = 3

        airports = reference.get_nearby(lat, lon, count=count)
        return Response(AirportSerializer(airports, many=True).data)
```

Replace `backend/apps/stations/views.py`:

```python
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from . import reference
from .serializers import StationSerializer

VALID_STATION_TYPES = {
    'major_station',
    'regional_station',
    'commuter_rail_station',
    'subway_station',
}


class NearestStationsView(APIView):
    """Return the N nearest train stations to a given latitude/longitude.

    Query params:
        lat (float): Latitude
        lon (float): Longitude
        count (int): Number of stations to return (default 3, max 10)
        station_type (str): Optional filter by station type
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            lat = float(request.query_params.get('lat'))
            lon = float(request.query_params.get('lon'))
        except (TypeError, ValueError):
            return Response(
                {'error': 'lat and lon query parameters are required and must be numbers.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            count = int(request.query_params.get('count', 3))
            count = min(max(count, 1), 10)
        except (TypeError, ValueError):
            count = 3

        station_type = request.query_params.get('station_type')
        if station_type not in VALID_STATION_TYPES:
            station_type = None

        stations = reference.get_nearby(lat, lon, count=count, station_type=station_type)
        return Response(StationSerializer(stations, many=True).data)
```

- [ ] **Step 5: Delete models, migrations, and admin registrations**

```bash
git rm backend/apps/airports/models.py backend/apps/stations/models.py
git rm -r backend/apps/airports/migrations backend/apps/stations/migrations
```

Replace `backend/apps/airports/admin.py` and `backend/apps/stations/admin.py` each with:

```python
# Airports and stations are static reference data held in an in-memory index
# (see reference.py), not database models, so there is nothing to register.
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `docker compose exec api poetry run python manage.py test apps.airports apps.stations apps.common -v 2`
Expected: PASS — all tests across the three modules

- [ ] **Step 7: Commit**

```bash
git add backend/apps/airports backend/apps/stations
git commit -m "refactor(airports,stations): serve reference data from memory, drop ORM models"
```

---

## Phase 2 — Emulator infrastructure

### Task 8: Firebase emulator + Firestore client

**Files:**
- Create: `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `.firebaserc` (repo root)
- Create: `backend/apps/common/firestore.py`, `backend/apps/common/exception_handlers.py`, `backend/apps/common/testing.py`
- Create: `docker/firebase-emulator/Dockerfile`
- Modify: `docker-compose.yml`, `backend/config/settings.py`, `backend/pyproject.toml`, `Makefile`
- Test: `backend/apps/common/tests/test_firestore.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `apps.common.firestore.get_client() -> google.cloud.firestore.Client`
  - `apps.common.firestore.collection(name: str)` — shorthand for `get_client().collection(name)`
  - `apps.common.testing.FirestoreTestMixin` — purges collections in `setUp`
  - `apps.common.exception_handlers.firestore_exception_handler`

- [ ] **Step 1: Add the dependency**

Modify `backend/pyproject.toml` — add to `dependencies`:

```toml
    "firebase-admin (>=6.5.0,<7.0.0)",
```

Run: `docker compose exec api poetry lock && docker compose exec api poetry install`
Expected: `firebase-admin` resolved and installed.

- [ ] **Step 2: Write the emulator config files**

Create `firebase.json`:

```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

The `auth` block is intentionally present but unused; ClickUp task 86bb3eu64 (Auth0 → GCIP) activates it.

Create `.firebaserc`:

```json
{
  "projects": {
    "default": "map-my-friends-local"
  }
}
```

Create `firestore.rules` — deny-all, because Django uses the Admin SDK which bypasses rules entirely:

```
rules_version = '2';

// Django reaches Firestore through the Admin SDK, which bypasses these rules.
// They exist as a safety floor: no direct client access is permitted.
// If the Flutter app is ever pointed at Firestore directly, these must be
// written properly before that ships.
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

Create `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "people",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "owner_key", "order": "ASCENDING" },
        { "fieldPath": "last_name", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "contact_logs",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "person_id", "order": "ASCENDING" },
        { "fieldPath": "contacted_at", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "trips",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "owner_key", "order": "ASCENDING" },
        { "fieldPath": "start_date", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

- [ ] **Step 3: Build the emulator service**

Create `docker/firebase-emulator/Dockerfile`:

```dockerfile
# The Firestore emulator is a Java process, so a JRE is required alongside
# the Node-based firebase-tools CLI.
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g firebase-tools@13

WORKDIR /workspace

EXPOSE 4000 8080 9099

CMD ["firebase", "emulators:start", \
     "--project", "map-my-friends-local", \
     "--only", "auth,firestore"]
```

Modify `docker-compose.yml` — delete the entire `db` service and the `postgres_data` volume, and replace with:

```yaml
services:
  # -----------------------------
  # BACKEND (Django)
  # -----------------------------
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    image: map-my-friends-backend
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - ./backend:/app # Syncs your local backend folder to the container
      - /app/.venv # Anonymous volume to hide host's .venv from container
      - media_data:/app/media # Persist uploaded media files
    ports:
      - "8000:8000"
    depends_on:
      - firestore
    environment:
      - FIRESTORE_EMULATOR_HOST=firestore:8080
      - FIRESTORE_PROJECT_ID=map-my-friends-local
      - DJANGO_DEBUG=True

  # -----------------------------
  # FIRESTORE + AUTH EMULATOR
  # -----------------------------
  firestore:
    build:
      context: ./docker/firebase-emulator
    volumes:
      - ./firebase.json:/workspace/firebase.json:ro
      - ./firestore.rules:/workspace/firestore.rules:ro
      - ./firestore.indexes.json:/workspace/firestore.indexes.json:ro
      - ./.firebaserc:/workspace/.firebaserc:ro
    ports:
      - "4000:4000" # Emulator UI
      - "8080:8080" # Firestore
      - "9099:9099" # Auth (unused until ClickUp 86bb3eu64)

volumes:
  media_data:
```

The emulator binds only to loopback by default; `firebase.json`'s `singleProjectMode` plus the container network make `firestore:8080` reachable from `api`. If connections are refused, add `"host": "0.0.0.0"` to each emulator block in `firebase.json`.

- [ ] **Step 4: Write the failing client test**

Create `backend/apps/common/tests/test_firestore.py`:

```python
from django.test import SimpleTestCase

from apps.common import firestore as fs
from apps.common.testing import FirestoreTestMixin


class FirestoreClientTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["_smoke"]

    def test_client_is_singleton(self):
        self.assertIs(fs.get_client(), fs.get_client())

    def test_round_trip_document(self):
        ref = fs.collection("_smoke").document("doc1")
        ref.set({"value": 42})
        self.assertEqual(ref.get().to_dict()["value"], 42)

    def test_purge_between_tests_leaves_collection_empty(self):
        # The mixin purges in setUp, so the document written by the previous
        # test must not be visible here.
        self.assertEqual(len(list(fs.collection("_smoke").stream())), 0)
```

- [ ] **Step 5: Run test to verify it fails**

Run: `docker compose up -d firestore && docker compose exec api poetry run python manage.py test apps.common.tests.test_firestore -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.firestore'`

- [ ] **Step 6: Write the client, exception handler, and test mixin**

Create `backend/apps/common/firestore.py`:

```python
"""Firestore client singleton.

firebase-admin detects FIRESTORE_EMULATOR_HOST itself and routes to the
emulator when it is set, so no application code branches on environment.
That is what makes local behaviour a faithful predictor of production.
"""

from __future__ import annotations

import os
import threading

import firebase_admin
from django.core.exceptions import ImproperlyConfigured
from firebase_admin import firestore

_lock = threading.Lock()
_client = None


def _check_configuration() -> None:
    from django.conf import settings

    if settings.DEBUG and not os.environ.get("FIRESTORE_EMULATOR_HOST"):
        raise ImproperlyConfigured(
            "FIRESTORE_EMULATOR_HOST is not set while DEBUG=True. Start the "
            "emulator with `make up` (or `docker compose up firestore`), which "
            "sets FIRESTORE_EMULATOR_HOST=firestore:8080 for the api service."
        )


def get_client():
    """Return the process-wide Firestore client, initialising it on first use."""
    global _client
    if _client is None:
        with _lock:
            if _client is None:
                from django.conf import settings

                _check_configuration()
                if not firebase_admin._apps:
                    firebase_admin.initialize_app(
                        options={"projectId": settings.FIRESTORE_PROJECT_ID}
                    )
                _client = firestore.client()
    return _client


def collection(name: str):
    """Shorthand for get_client().collection(name)."""
    return get_client().collection(name)
```

Create `backend/apps/common/exception_handlers.py`:

```python
"""Central mapping of Firestore transport errors to DRF responses.

Handled here rather than per-view so every endpoint degrades identically.
"""

from google.api_core import exceptions as gcloud_exceptions
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


def firestore_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is not None:
        return response

    if isinstance(
        exc, (gcloud_exceptions.ServiceUnavailable, gcloud_exceptions.DeadlineExceeded)
    ):
        return Response(
            {"error": "Data store temporarily unavailable. Please retry."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    if isinstance(exc, gcloud_exceptions.NotFound):
        return Response({"error": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    # PermissionDenied indicates misconfigured credentials, never a user-facing
    # condition. Returning None lets Django produce a 500 and log the trace.
    return None
```

Create `backend/apps/common/testing.py`:

```python
"""Test support for emulator-backed tests.

Tests run against the real Firestore emulator rather than mocks, so state must
be purged between them. Mocking would only verify assumptions about Firestore
rather than Firestore itself.
"""

from __future__ import annotations

from apps.common import firestore as fs


def purge_collection(name: str, batch_size: int = 200) -> None:
    """Recursively delete every document in a collection, including subcollections."""
    collection = fs.collection(name)
    while True:
        docs = list(collection.limit(batch_size).stream())
        if not docs:
            return
        for doc in docs:
            for sub in doc.reference.collections():
                for sub_doc in sub.stream():
                    sub_doc.reference.delete()
            doc.reference.delete()


class FirestoreTestMixin:
    """Purges the named collections before each test.

    Usage:
        class MyTests(FirestoreTestMixin, APITestCase):
            collections_to_purge = ["people", "trips"]
    """

    collections_to_purge: list[str] = ["people", "trips", "user_profiles"]

    def setUp(self):
        for name in self.collections_to_purge:
            purge_collection(name)
        super().setUp()
```

- [ ] **Step 7: Wire settings**

Modify `backend/config/settings.py` — add near the Auth0 configuration block at the end:

```python
# Firestore Configuration
# firebase-admin auto-detects FIRESTORE_EMULATOR_HOST; when it is set the
# client talks to the local emulator and no credentials are required.
FIRESTORE_PROJECT_ID = os.environ.get('FIRESTORE_PROJECT_ID', 'map-my-friends-local')
```

And add `'EXCEPTION_HANDLER'` inside the existing `REST_FRAMEWORK` dict:

```python
    'EXCEPTION_HANDLER': 'apps.common.exception_handlers.firestore_exception_handler',
```

Add `'apps.common',` to `INSTALLED_APPS` immediately before `'apps.users',`.

- [ ] **Step 8: Add the Makefile emulator target**

Modify `Makefile` — replace the `db:` target with:

```make
emulator:
	docker compose up firestore

ui:
	@echo "Emulator UI: http://localhost:4000"
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `docker compose up -d --build firestore && docker compose exec api poetry run python manage.py test apps.common -v 2`
Expected: PASS — all `apps.common` tests including the three Firestore round-trip tests

- [ ] **Step 10: Commit**

```bash
git add firebase.json firestore.rules firestore.indexes.json .firebaserc \
        docker/firebase-emulator/Dockerfile docker-compose.yml Makefile \
        backend/apps/common backend/config/settings.py backend/pyproject.toml backend/poetry.lock
git commit -m "feat(firestore): add emulator suite, client singleton, and error mapping"
```

---

## Phase 3 — User data to Firestore

### Task 9: Storage abstraction

**Files:**
- Create: `backend/apps/common/storage.py`
- Modify: `backend/config/settings.py`
- Test: `backend/apps/common/tests/test_storage.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `save_upload(uploaded_file, prefix: str) -> str` — persists the file, returns its storage name
  - `upload_url(name: str | None, request=None) -> str | None` — absolute URL for a stored name

`ImageField` machinery leaves with the models, so uploads must be handled explicitly. `STORAGES` keeps the backend swappable — filesystem locally, GCS in production — with no code change.

- [ ] **Step 1: Write the failing test**

Create `backend/apps/common/tests/test_storage.py`:

```python
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase

from apps.common.storage import save_upload, upload_url


class StorageTests(SimpleTestCase):
    def test_save_upload_returns_prefixed_name(self):
        upload = SimpleUploadedFile("avatar.png", b"fake-image-bytes", content_type="image/png")
        name = save_upload(upload, prefix="profile_images")
        self.assertTrue(name.startswith("profile_images/"))
        self.assertTrue(name.endswith(".png"))

    def test_saved_names_do_not_collide(self):
        first = save_upload(
            SimpleUploadedFile("a.png", b"one", content_type="image/png"),
            prefix="profile_images",
        )
        second = save_upload(
            SimpleUploadedFile("a.png", b"two", content_type="image/png"),
            prefix="profile_images",
        )
        self.assertNotEqual(first, second)

    def test_upload_url_returns_media_url(self):
        name = save_upload(
            SimpleUploadedFile("b.png", b"bytes", content_type="image/png"),
            prefix="profile_images",
        )
        self.assertIn("/media/profile_images/", upload_url(name))

    def test_upload_url_of_none_is_none(self):
        self.assertIsNone(upload_url(None))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_storage -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.common.storage'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/common/storage.py`:

```python
"""File storage helpers.

Django's ImageField previously handled naming, saving and URL generation. With
the models gone those steps become explicit. Everything routes through
`default_storage`, so the STORAGES setting alone decides between the local
filesystem and Cloud Storage — no code branches on environment.
"""

from __future__ import annotations

import uuid
from pathlib import Path

from django.core.files.storage import default_storage


def save_upload(uploaded_file, prefix: str) -> str:
    """Persist an uploaded file under `prefix/`, returning its storage name.

    A UUID stem prevents collisions between users uploading identically named
    files, mirroring what Django's upload_to + suffixing used to provide.
    """
    suffix = Path(uploaded_file.name).suffix.lower()
    name = f"{prefix}/{uuid.uuid4().hex}{suffix}"
    return default_storage.save(name, uploaded_file)


def upload_url(name: str | None, request=None) -> str | None:
    """Absolute URL for a stored file name, or None when unset."""
    if not name:
        return None
    url = default_storage.url(name)
    if request is not None:
        return request.build_absolute_uri(url)
    return url
```

- [ ] **Step 4: Wire the STORAGES setting**

Modify `backend/config/settings.py` — replace the `STATICFILES_STORAGE` line with a unified `STORAGES` dict (that setting is deprecated in Django 6):

```python
# Storage backends. Swapping "default" to django-storages' GoogleCloudStorage
# is the entire production change — see spec section 7. Cloud Run has an
# ephemeral filesystem, so local disk is not viable there.
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.common.tests.test_storage -v 2`
Expected: PASS — 4 tests

- [ ] **Step 6: Commit**

```bash
git add backend/apps/common/storage.py backend/apps/common/tests/test_storage.py backend/config/settings.py
git commit -m "feat(common): add storage abstraction over Django STORAGES"
```

---

### Task 10: Geocoding service

**Files:**
- Create: `backend/apps/people/services.py`
- Test: `backend/apps/people/tests_services.py`

**Interfaces:**
- Consumes: nothing
- Produces: `geocode_address(city: str, state: str, country: str, street: str | None = None) -> tuple[float, float, str | None]` returning `(lat, lng, timezone)`, raising `django.core.exceptions.ValidationError` on failure

Extracted verbatim from `Person.save()` so it can be tested in isolation instead of firing as a save side effect.

- [ ] **Step 1: Write the failing test**

Create `backend/apps/people/tests_services.py`:

```python
from unittest.mock import MagicMock, patch

from django.core.exceptions import ValidationError
from django.test import SimpleTestCase

from apps.people.services import geocode_address


class GeocodeAddressTests(SimpleTestCase):
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_returns_coordinates_and_timezone(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = MagicMock(
            latitude=41.8781, longitude=-87.6298
        )
        mock_tf.return_value.timezone_at.return_value = "America/Chicago"

        lat, lng, tz = geocode_address("Chicago", "IL", "USA")

        self.assertAlmostEqual(lat, 41.8781)
        self.assertAlmostEqual(lng, -87.6298)
        self.assertEqual(tz, "America/Chicago")

    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_raises_validation_error_when_not_found(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = None

        with self.assertRaises(ValidationError):
            geocode_address("Nowhereville", "ZZ", "XX")

    @patch("apps.people.services.time.sleep")
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_retries_on_timeout_then_succeeds(self, mock_nominatim, mock_tf, mock_sleep):
        from geopy.exc import GeocoderTimedOut

        mock_nominatim.return_value.geocode.side_effect = [
            GeocoderTimedOut(),
            MagicMock(latitude=1.0, longitude=2.0),
        ]
        mock_tf.return_value.timezone_at.return_value = "UTC"

        lat, lng, tz = geocode_address("Somewhere", "ST", "CC")

        self.assertEqual((lat, lng, tz), (1.0, 2.0, "UTC"))
        self.assertEqual(mock_nominatim.return_value.geocode.call_count, 2)

    @patch("apps.people.services.time.sleep")
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_raises_after_exhausting_retries(self, mock_nominatim, mock_tf, mock_sleep):
        from geopy.exc import GeocoderServiceError

        mock_nominatim.return_value.geocode.side_effect = GeocoderServiceError()

        with self.assertRaises(ValidationError):
            geocode_address("Somewhere", "ST", "CC")

    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_street_included_in_query_when_provided(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = MagicMock(
            latitude=1.0, longitude=2.0
        )
        mock_tf.return_value.timezone_at.return_value = "UTC"

        geocode_address("Chicago", "IL", "USA", street="123 Main St")

        query = mock_nominatim.return_value.geocode.call_args[0][0]
        self.assertEqual(query["street"], "123 Main St")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.people.tests_services -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.people.services'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/people/services.py`:

```python
"""Address geocoding.

Lifted out of Person.save() when the model moved to Firestore. Behaviour is
unchanged — same structured Nominatim query, same three attempts, same
ValidationError on failure — but it is now an explicit call the repository
makes, which also makes it testable without touching the datastore.
"""

from __future__ import annotations

import time

from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from geopy.exc import GeocoderServiceError, GeocoderTimedOut
from geopy.geocoders import Nominatim
from timezonefinder import TimezoneFinder

USER_AGENT = "map_my_friends_global_connect"
MAX_ATTEMPTS = 3


def geocode_address(
    city: str,
    state: str,
    country: str,
    street: str | None = None,
) -> tuple[float, float, str | None]:
    """Resolve an address to (latitude, longitude, timezone).

    Raises ValidationError if the address cannot be resolved or the service is
    unavailable after MAX_ATTEMPTS.
    """
    geolocator = Nominatim(user_agent=USER_AGENT)
    finder = TimezoneFinder()

    # Structured query gives better international accuracy than a free-text one.
    query = {"city": city, "state": state, "country": country}
    if street:
        query["street"] = street

    for attempt in range(MAX_ATTEMPTS):
        try:
            location = geolocator.geocode(query)
        except (GeocoderTimedOut, GeocoderServiceError):
            if attempt < MAX_ATTEMPTS - 1:
                time.sleep(1)
                continue
            raise ValidationError(
                _("Geocoding service unavailable. Please try again later.")
            )

        if location:
            timezone = finder.timezone_at(lng=location.longitude, lat=location.latitude)
            return location.latitude, location.longitude, timezone
        break

    address = ", ".join(filter(None, [street or "", city, state, country])).strip(", ")
    raise ValidationError(
        _("Could not geocode address: %(address)s") % {"address": address}
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.people.tests_services -v 2`
Expected: PASS — 5 tests

- [ ] **Step 5: Commit**

```bash
git add backend/apps/people/services.py backend/apps/people/tests_services.py
git commit -m "feat(people): extract geocoding from Person.save into testable service"
```

---

### Task 11: Person + ContactLog repositories

**Files:**
- Create: `backend/apps/people/repositories.py`
- Test: `backend/apps/people/tests_repositories.py`

**Interfaces:**
- Consumes: `apps.common.firestore.collection`, `apps.common.testing.FirestoreTestMixin`
- Produces:
  - `PersonRecord` dataclass — `id: str`, `owner_key: str | None`, plus all person fields, `lat`, `lng`, `last_contacted_at: str | None`, `last_contact_channel: str | None`
  - `ContactLogRecord` dataclass — `id: str`, `person_id: str`, `channel: str`, `contacted_at: str`, `note: str | None`, `created_at: str`
  - `PersonRepository`: `list_for_owner(owner_key)`, `get_for_owner(person_id, owner_key)`, `create(owner_key, data)`, `update(person_id, owner_key, data)`, `delete(person_id, owner_key)`
  - `ContactLogRepository`: `list_for_owner(owner_key, person_id=None)`, `create(owner_key, person_id, data)`, `get_for_owner(log_id, owner_key)`, `update(log_id, owner_key, data)`, `delete(log_id, owner_key)`

**Every read method requires `owner_key`.** There is deliberately no unscoped read, so the isolation asserted by `tests/test_api_security.py` cannot be bypassed by forgetting a filter.

- [ ] **Step 1: Write the failing test**

Create `backend/apps/people/tests_repositories.py`:

```python
from django.test import SimpleTestCase

from apps.common.testing import FirestoreTestMixin
from apps.people.repositories import ContactLogRepository, PersonRepository

PERSON_DATA = {
    "tag": "FRIEND",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "city": "London",
    "state": "England",
    "country": "UK",
    "lat": 51.5074,
    "lng": -0.1278,
}


class PersonRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()

    def test_create_assigns_string_id(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsInstance(person.id, str)
        self.assertTrue(person.id)

    def test_create_sets_owner_key(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertEqual(person.owner_key, "owner-a")

    def test_list_returns_only_own_people(self):
        self.people.create("owner-a", PERSON_DATA)
        self.people.create("owner-b", PERSON_DATA)
        self.assertEqual(len(self.people.list_for_owner("owner-a")), 1)

    def test_list_for_none_owner_returns_public_people(self):
        self.people.create(None, PERSON_DATA)
        self.people.create("owner-a", PERSON_DATA)
        public = self.people.list_for_owner(None)
        self.assertEqual(len(public), 1)
        self.assertIsNone(public[0].owner_key)

    def test_get_for_wrong_owner_returns_none(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsNone(self.people.get_for_owner(person.id, "owner-b"))

    def test_get_for_correct_owner_returns_record(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertEqual(self.people.get_for_owner(person.id, "owner-a").id, person.id)

    def test_update_applies_changes(self):
        person = self.people.create("owner-a", PERSON_DATA)
        updated = self.people.update(person.id, "owner-a", {"first_name": "Grace"})
        self.assertEqual(updated.first_name, "Grace")

    def test_update_by_wrong_owner_returns_none(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertIsNone(self.people.update(person.id, "owner-b", {"first_name": "Nope"}))

    def test_delete_removes_document(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertTrue(self.people.delete(person.id, "owner-a"))
        self.assertIsNone(self.people.get_for_owner(person.id, "owner-a"))

    def test_delete_by_wrong_owner_is_refused(self):
        person = self.people.create("owner-a", PERSON_DATA)
        self.assertFalse(self.people.delete(person.id, "owner-b"))
        self.assertIsNotNone(self.people.get_for_owner(person.id, "owner-a"))


class ContactLogRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.people = PersonRepository()
        self.logs = ContactLogRepository()
        self.person_a = self.people.create("owner-a", PERSON_DATA)
        self.person_b = self.people.create("owner-b", PERSON_DATA)

    def test_create_log_for_own_person(self):
        log = self.logs.create(
            "owner-a",
            self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.assertEqual(log.person_id, self.person_a.id)

    def test_cannot_create_log_for_another_owners_person(self):
        log = self.logs.create(
            "owner-a",
            self.person_b.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.assertIsNone(log)

    def test_list_is_scoped_to_owner(self):
        self.logs.create(
            "owner-a", self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.logs.create(
            "owner-b", self.person_b.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-02T12:00:00+00:00"},
        )
        self.assertEqual(len(self.logs.list_for_owner("owner-a")), 1)

    def test_person_filter_scoped_to_owner(self):
        self.logs.create(
            "owner-a", self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        # Filtering by another owner's person yields nothing, not a leak.
        self.assertEqual(
            self.logs.list_for_owner("owner-a", person_id=self.person_b.id), []
        )

    def test_logs_ordered_most_recent_first(self):
        self.logs.create(
            "owner-a", self.person_a.id,
            {"channel": "CALL", "contacted_at": "2026-07-01T12:00:00+00:00"},
        )
        self.logs.create(
            "owner-a", self.person_a.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-05T12:00:00+00:00"},
        )
        logs = self.logs.list_for_owner("owner-a", person_id=self.person_a.id)
        self.assertEqual(logs[0].channel, "VIDEO")

    def test_person_carries_recency_summary(self):
        self.logs.create(
            "owner-a", self.person_a.id,
            {"channel": "VIDEO", "contacted_at": "2026-07-05T12:00:00+00:00"},
        )
        person = self.people.get_for_owner(self.person_a.id, "owner-a")
        self.assertEqual(person.last_contact_channel, "VIDEO")
        self.assertTrue(person.last_contacted_at.startswith("2026-07-05"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.people.tests_repositories -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.people.repositories'`

- [ ] **Step 3: Write minimal implementation**

Create `backend/apps/people/repositories.py`:

```python
"""Firestore repositories for Person and ContactLog.

Every read method takes an owner_key and there is no unscoped alternative.
Ownership isolation is therefore structural rather than a filter a caller can
forget — the property the security suite in tests/test_api_security.py asserts.

Layout:
    people/{personId}                 owner_key: str | None  (None = public)
      └── contact_logs/{logId}
"""

from __future__ import annotations

from dataclasses import dataclass, field, fields
from datetime import datetime, timezone

from apps.common import firestore as fs

PEOPLE = "people"
CONTACT_LOGS = "contact_logs"


@dataclass
class PersonRecord:
    id: str
    owner_key: str | None = None
    tag: str = ""
    first_name: str = ""
    last_name: str = ""
    city: str = ""
    state: str = ""
    country: str = ""
    street: str | None = None
    birthday: str | None = None
    phone_number: str | None = None
    profile_image: str | None = None
    lat: float | None = None
    lng: float | None = None
    timezone: str | None = None
    pin_color: str = "#F44336"
    pin_style: str = "teardrop"
    pin_icon_type: str = "none"
    pin_emoji: str | None = None
    contact_cadence_days: int | None = None
    preferred_airport: int | None = None
    preferred_station: int | None = None
    last_contacted_at: str | None = None
    last_contact_channel: str | None = None


@dataclass
class ContactLogRecord:
    id: str
    person_id: str
    channel: str
    contacted_at: str
    note: str | None = None
    created_at: str | None = None


_PERSON_FIELDS = {f.name for f in fields(PersonRecord)} - {"id"}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class PersonRepository:
    def _collection(self):
        return fs.collection(PEOPLE)

    def _hydrate(self, doc) -> PersonRecord:
        data = doc.to_dict() or {}
        record = PersonRecord(
            id=doc.id,
            **{k: v for k, v in data.items() if k in _PERSON_FIELDS},
        )
        latest = self._latest_log(doc.reference)
        if latest is not None:
            record.last_contacted_at = latest.get("contacted_at")
            record.last_contact_channel = latest.get("channel")
        return record

    def _latest_log(self, person_ref) -> dict | None:
        docs = list(
            person_ref.collection(CONTACT_LOGS)
            .order_by("contacted_at", direction="DESCENDING")
            .limit(1)
            .stream()
        )
        return docs[0].to_dict() if docs else None

    def list_for_owner(self, owner_key: str | None) -> list[PersonRecord]:
        query = self._collection().where("owner_key", "==", owner_key)
        return [self._hydrate(doc) for doc in query.stream()]

    def get_for_owner(self, person_id: str, owner_key: str | None) -> PersonRecord | None:
        doc = self._collection().document(person_id).get()
        if not doc.exists:
            return None
        if (doc.to_dict() or {}).get("owner_key") != owner_key:
            return None
        return self._hydrate(doc)

    def create(self, owner_key: str | None, data: dict) -> PersonRecord:
        payload = {k: v for k, v in data.items() if k in _PERSON_FIELDS}
        payload["owner_key"] = owner_key
        payload["created_at"] = _now_iso()
        payload["updated_at"] = _now_iso()

        ref = self._collection().document()
        ref.set(payload)
        return self._hydrate(ref.get())

    def update(self, person_id: str, owner_key: str | None, data: dict) -> PersonRecord | None:
        ref = self._collection().document(person_id)
        doc = ref.get()
        if not doc.exists or (doc.to_dict() or {}).get("owner_key") != owner_key:
            return None

        payload = {k: v for k, v in data.items() if k in _PERSON_FIELDS}
        payload["updated_at"] = _now_iso()
        ref.update(payload)
        return self._hydrate(ref.get())

    def delete(self, person_id: str, owner_key: str | None) -> bool:
        ref = self._collection().document(person_id)
        doc = ref.get()
        if not doc.exists or (doc.to_dict() or {}).get("owner_key") != owner_key:
            return False

        for log in ref.collection(CONTACT_LOGS).stream():
            log.reference.delete()
        ref.delete()
        return True


class ContactLogRepository:
    def __init__(self):
        self._people = PersonRepository()

    def _person_ref_if_owned(self, person_id: str, owner_key: str | None):
        ref = fs.collection(PEOPLE).document(person_id)
        doc = ref.get()
        if not doc.exists or (doc.to_dict() or {}).get("owner_key") != owner_key:
            return None
        return ref

    def _hydrate(self, doc, person_id: str) -> ContactLogRecord:
        data = doc.to_dict() or {}
        return ContactLogRecord(
            id=doc.id,
            person_id=person_id,
            channel=data.get("channel", ""),
            contacted_at=data.get("contacted_at", ""),
            note=data.get("note"),
            created_at=data.get("created_at"),
        )

    def list_for_owner(
        self, owner_key: str | None, person_id: str | None = None
    ) -> list[ContactLogRecord]:
        if person_id is not None:
            ref = self._person_ref_if_owned(person_id, owner_key)
            if ref is None:
                return []
            person_refs = [ref]
        else:
            person_refs = [
                fs.collection(PEOPLE).document(p.id)
                for p in self._people.list_for_owner(owner_key)
            ]

        records: list[ContactLogRecord] = []
        for ref in person_refs:
            for doc in (
                ref.collection(CONTACT_LOGS)
                .order_by("contacted_at", direction="DESCENDING")
                .stream()
            ):
                records.append(self._hydrate(doc, ref.id))

        records.sort(key=lambda r: r.contacted_at, reverse=True)
        return records

    def get_for_owner(self, log_id: str, owner_key: str | None) -> ContactLogRecord | None:
        for record in self.list_for_owner(owner_key):
            if record.id == log_id:
                return record
        return None

    def create(
        self, owner_key: str | None, person_id: str, data: dict
    ) -> ContactLogRecord | None:
        person_ref = self._person_ref_if_owned(person_id, owner_key)
        if person_ref is None:
            return None

        payload = {
            "channel": data["channel"],
            "contacted_at": data["contacted_at"],
            "note": data.get("note"),
            "created_at": _now_iso(),
        }
        ref = person_ref.collection(CONTACT_LOGS).document()
        ref.set(payload)
        return self._hydrate(ref.get(), person_id)

    def update(self, log_id: str, owner_key: str | None, data: dict) -> ContactLogRecord | None:
        existing = self.get_for_owner(log_id, owner_key)
        if existing is None:
            return None

        ref = (
            fs.collection(PEOPLE)
            .document(existing.person_id)
            .collection(CONTACT_LOGS)
            .document(log_id)
        )
        payload = {
            k: v for k, v in data.items() if k in {"channel", "contacted_at", "note"}
        }
        ref.update(payload)
        return self._hydrate(ref.get(), existing.person_id)

    def delete(self, log_id: str, owner_key: str | None) -> bool:
        existing = self.get_for_owner(log_id, owner_key)
        if existing is None:
            return False

        fs.collection(PEOPLE).document(existing.person_id).collection(
            CONTACT_LOGS
        ).document(log_id).delete()
        return True
```

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec api poetry run python manage.py test apps.people.tests_repositories -v 2`
Expected: PASS — 16 tests

- [ ] **Step 5: Commit**

```bash
git add backend/apps/people/repositories.py backend/apps/people/tests_repositories.py
git commit -m "feat(people): add owner-scoped Firestore repositories for Person and ContactLog"
```

---

### Task 12: Person + ContactLog API layer

**Files:**
- Modify: `backend/apps/people/serializers.py` (rewrite), `backend/apps/people/views.py` (rewrite), `backend/apps/people/admin.py` (empty out)
- Delete: `backend/apps/people/models.py`, `backend/apps/people/migrations/`
- Test: `backend/apps/people/tests.py` (rewrite)

**Interfaces:**
- Consumes: `PersonRepository`, `ContactLogRepository`, `geocode_address`, `AirportSerializer`, `StationSerializer`, `GeoFeatureSerializer`, `save_upload`, `upload_url`
- Produces: unchanged HTTP contract at `/api/people/` and `/api/contact-logs/`

Public/authenticated gating carries over exactly: list and retrieve are `AllowAny` (unauthenticated callers see only `owner_key == None` people), writes require authentication, and `last_contacted_at` / `last_contact_channel` are stripped for anonymous callers.

- [ ] **Step 1: Rewrite the serializers**

Replace `backend/apps/people/serializers.py`:

```python
from rest_framework import serializers

from apps.airports import reference as airport_reference
from apps.airports.serializers import AirportSerializer
from apps.common.serializers import GeoFeatureSerializer
from apps.stations import reference as station_reference
from apps.stations.serializers import StationSerializer

TAG_CHOICES = ["FRIEND", "FAMILY"]
PIN_STYLE_CHOICES = ["teardrop", "circle", "square", "triangle", "diamond"]
PIN_ICON_TYPE_CHOICES = ["none", "emoji", "initials", "picture"]
CHANNEL_CHOICES = ["CALL", "VIDEO", "MESSAGE"]


class ContactLogSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    person = serializers.CharField(source="person_id")
    channel = serializers.ChoiceField(choices=CHANNEL_CHOICES)
    contacted_at = serializers.DateTimeField()
    note = serializers.CharField(max_length=280, required=False, allow_null=True, allow_blank=True)
    created_at = serializers.DateTimeField(read_only=True)


class PersonSerializer(GeoFeatureSerializer):
    id = serializers.CharField(read_only=True)
    owner = serializers.CharField(source="owner_key", read_only=True)
    tag = serializers.ChoiceField(choices=TAG_CHOICES)
    first_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    city = serializers.CharField(max_length=100, required=False, allow_blank=True)
    state = serializers.CharField(max_length=100, required=False, allow_blank=True)
    country = serializers.CharField(max_length=100, required=False, allow_blank=True)
    street = serializers.CharField(max_length=255, required=False, allow_null=True, allow_blank=True)
    birthday = serializers.DateField(required=False, allow_null=True)
    phone_number = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    profile_image = serializers.SerializerMethodField()
    lat = serializers.FloatField(read_only=True)
    lng = serializers.FloatField(read_only=True)
    timezone = serializers.CharField(read_only=True, allow_null=True)
    pin_color = serializers.CharField(max_length=20, required=False)
    pin_style = serializers.ChoiceField(choices=PIN_STYLE_CHOICES, required=False)
    pin_icon_type = serializers.ChoiceField(choices=PIN_ICON_TYPE_CHOICES, required=False)
    pin_emoji = serializers.CharField(max_length=10, required=False, allow_null=True, allow_blank=True)
    contact_cadence_days = serializers.IntegerField(required=False, allow_null=True, min_value=0)
    preferred_airport = serializers.IntegerField(required=False, allow_null=True)
    preferred_station = serializers.IntegerField(required=False, allow_null=True)
    preferred_airport_detail = serializers.SerializerMethodField()
    preferred_station_detail = serializers.SerializerMethodField()
    last_contacted_at = serializers.CharField(read_only=True, allow_null=True)
    last_contact_channel = serializers.CharField(read_only=True, allow_null=True)

    def get_profile_image(self, obj):
        from apps.common.storage import upload_url

        return upload_url(getattr(obj, "profile_image", None), self.context.get("request"))

    def get_preferred_airport_detail(self, obj):
        if not obj.preferred_airport:
            return None
        airport = airport_reference.get_by_id(obj.preferred_airport)
        return AirportSerializer(airport).data if airport else None

    def get_preferred_station_detail(self, obj):
        if not obj.preferred_station:
            return None
        station = station_reference.get_by_id(obj.preferred_station)
        return StationSerializer(station).data if station else None

    def validate_preferred_airport(self, value):
        if value is not None and airport_reference.get_by_id(value) is None:
            raise serializers.ValidationError("Unknown airport id.")
        return value

    def validate_preferred_station(self, value):
        if value is not None and station_reference.get_by_id(value) is None:
            raise serializers.ValidationError("Unknown station id.")
        return value

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get("request")
        is_authenticated = bool(request and request.user and request.user.is_authenticated)
        if not is_authenticated:
            ret["properties"].pop("last_contacted_at", None)
            ret["properties"].pop("last_contact_channel", None)
        return ret
```

- [ ] **Step 2: Rewrite the views**

Replace `backend/apps/people/views.py`:

```python
from rest_framework import status, viewsets
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from apps.common.storage import save_upload

from .repositories import ContactLogRepository, PersonRepository
from .serializers import ContactLogSerializer, PersonSerializer
from .services import geocode_address


def owner_key_for(request):
    """Firestore ownership key for a request; None means the public dataset."""
    user = request.user
    if user and user.is_authenticated:
        return user.username
    return None


class PersonViewSet(viewsets.ViewSet):
    """Manage Person documents.

    List and retrieve are public (anonymous callers see only unowned people);
    create, update and delete require authentication.
    """

    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            permission_classes = [AllowAny]
        else:
            permission_classes = [IsAuthenticated]
        return [permission() for permission in permission_classes]

    def get_throttles(self):
        if self.action == 'create':
            # Stricter throttling for creating people due to geocoding costs
            return [UserRateThrottle()]
        return super().get_throttles()

    @property
    def repository(self):
        return PersonRepository()

    def list(self, request):
        people = self.repository.list_for_owner(owner_key_for(request))
        serializer = PersonSerializer(people, many=True, context={'request': request})
        return Response(serializer.data)

    def retrieve(self, request, pk=None):
        person = self.repository.get_for_owner(pk, owner_key_for(request))
        if person is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(PersonSerializer(person, context={'request': request}).data)

    def create(self, request):
        serializer = PersonSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        payload = dict(serializer.validated_data)
        payload = self._apply_geocoding(payload)
        payload = self._apply_upload(request, payload)

        person = self.repository.create(owner_key_for(request), payload)
        return Response(
            PersonSerializer(person, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )

    def update(self, request, pk=None):
        return self._write_update(request, pk, partial=False)

    def partial_update(self, request, pk=None):
        return self._write_update(request, pk, partial=True)

    def _write_update(self, request, pk, partial):
        serializer = PersonSerializer(
            data=request.data, partial=partial, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        payload = dict(serializer.validated_data)
        if any(k in payload for k in ('city', 'state', 'country', 'street')):
            payload = self._apply_geocoding(payload)
        payload = self._apply_upload(request, payload)

        person = self.repository.update(pk, owner_key_for(request), payload)
        if person is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(PersonSerializer(person, context={'request': request}).data)

    def destroy(self, request, pk=None):
        if not self.repository.delete(pk, owner_key_for(request)):
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)

    def _apply_geocoding(self, payload):
        lat, lng, timezone = geocode_address(
            payload.get('city', ''),
            payload.get('state', ''),
            payload.get('country', ''),
            payload.get('street'),
        )
        payload['lat'] = lat
        payload['lng'] = lng
        payload['timezone'] = timezone
        return payload

    def _apply_upload(self, request, payload):
        uploaded = request.FILES.get('profile_image')
        if uploaded is not None:
            payload['profile_image'] = save_upload(uploaded, prefix='profile_images')
        return payload


class ContactLogViewSet(viewsets.ViewSet):
    """Log touchpoints with a Person. All actions require authentication.

    Supports `?person=<id>` to scope the list to a single person.
    """

    permission_classes = [IsAuthenticated]

    @property
    def repository(self):
        return ContactLogRepository()

    def list(self, request):
        logs = self.repository.list_for_owner(
            owner_key_for(request), person_id=request.query_params.get('person')
        )
        return Response(ContactLogSerializer(logs, many=True).data)

    def retrieve(self, request, pk=None):
        log = self.repository.get_for_owner(pk, owner_key_for(request))
        if log is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(ContactLogSerializer(log).data)

    def create(self, request):
        serializer = ContactLogSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = dict(serializer.validated_data)
        person_id = payload.pop('person_id')
        payload['contacted_at'] = payload['contacted_at'].isoformat()

        log = self.repository.create(owner_key_for(request), person_id, payload)
        if log is None:
            # The person is absent or belongs to another owner. 400 mirrors the
            # previous queryset-restricted PrimaryKeyRelatedField behaviour.
            return Response(
                {'person': ['Invalid person.']}, status=status.HTTP_400_BAD_REQUEST
            )
        return Response(ContactLogSerializer(log).data, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        return self._write_update(request, pk, partial=False)

    def partial_update(self, request, pk=None):
        return self._write_update(request, pk, partial=True)

    def _write_update(self, request, pk, partial):
        serializer = ContactLogSerializer(data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        payload = dict(serializer.validated_data)
        payload.pop('person_id', None)
        if 'contacted_at' in payload:
            payload['contacted_at'] = payload['contacted_at'].isoformat()

        log = self.repository.update(pk, owner_key_for(request), payload)
        if log is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(ContactLogSerializer(log).data)

    def destroy(self, request, pk=None):
        if not self.repository.delete(pk, owner_key_for(request)):
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)
```

- [ ] **Step 3: Delete models, migrations and admin**

```bash
git rm backend/apps/people/models.py
git rm -r backend/apps/people/migrations
```

Replace `backend/apps/people/admin.py` with:

```python
# Person and ContactLog live in Firestore, not the ORM. Inspect them through
# the emulator UI (http://localhost:4000) locally, or the Firestore Console.
```

- [ ] **Step 4: Rewrite the app tests**

Replace `backend/apps/people/tests.py`:

```python
from unittest.mock import patch

from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from apps.common.testing import FirestoreTestMixin

PERSON_PAYLOAD = {
    "tag": "FRIEND",
    "first_name": "Ada",
    "last_name": "Lovelace",
    "city": "London",
    "state": "England",
    "country": "UK",
}


@patch(
    "apps.people.views.geocode_address",
    return_value=(51.5074, -0.1278, "Europe/London"),
)
class PersonEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["people"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")
        self.other = User.objects.create_user(username="owner-b", password="pw12345!")

    def test_list_is_public(self, _geocode):
        response = self.client.get("/api/people/")
        self.assertEqual(response.status_code, 200)

    def test_create_requires_auth(self, _geocode):
        response = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")
        self.assertEqual(response.status_code, 401)

    def test_create_returns_geojson_feature(self, _geocode):
        self.client.force_authenticate(user=self.user)
        response = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["type"], "Feature")
        self.assertEqual(response.data["geometry"]["coordinates"], [-0.1278, 51.5074])

    def test_owner_isolation_on_list(self, _geocode):
        self.client.force_authenticate(user=self.user)
        self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=self.other)
        response = self.client.get("/api/people/")
        self.assertEqual(len(response.data), 0)

    def test_cannot_retrieve_another_owners_person(self, _geocode):
        self.client.force_authenticate(user=self.user)
        created = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")
        person_id = created.data["id"]

        self.client.force_authenticate(user=self.other)
        response = self.client.get(f"/api/people/{person_id}/")
        self.assertEqual(response.status_code, 404)

    def test_cannot_delete_another_owners_person(self, _geocode):
        self.client.force_authenticate(user=self.user)
        created = self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=self.other)
        response = self.client.delete(f"/api/people/{created.data['id']}/")
        self.assertEqual(response.status_code, 404)

    def test_recency_fields_hidden_from_anonymous(self, _geocode):
        self.client.force_authenticate(user=self.user)
        self.client.post("/api/people/", PERSON_PAYLOAD, format="json")

        self.client.force_authenticate(user=None)
        response = self.client.get("/api/people/")
        for feature in response.data:
            self.assertNotIn("last_contacted_at", feature["properties"])
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `docker compose exec api poetry run python manage.py test apps.people -v 2`
Expected: PASS — repository, service and endpoint tests all green

- [ ] **Step 6: Commit**

```bash
git add backend/apps/people
git commit -m "refactor(people): serve Person and ContactLog from Firestore repositories"
```

---

### Task 13: Trip repositories and API layer

**Files:**
- Create: `backend/apps/trips/repositories.py`
- Modify: `backend/apps/trips/serializers.py`, `backend/apps/trips/views.py`, `backend/apps/trips/admin.py`
- Delete: `backend/apps/trips/models.py`, `backend/apps/trips/migrations/`
- Test: `backend/apps/trips/tests.py` (rewrite)

**Interfaces:**
- Consumes: `apps.common.firestore`, `apps.airports.reference`, `apps.stations.reference`
- Produces:
  - `TripRecord` — `id: str`, `owner_key: str`, `name: str`, `date: str`, `start_date: str`, `end_date: str`, `status: str`
  - `TripStopRecord` — `id: str`, `trip_id: str`, `sequence_order: int`, `lat: float`, `lng: float`, `person_ids: list[str]`, `airport_id: int | None`, `station_id: int | None`, `snapshot_address: str`, `snapshot_metadata: dict`
  - `TripLegRecord` — `id: str`, `trip_id: str`, `departure_stop_id: str`, `arrival_stop_id: str`, `departure_time: str | None`, `arrival_time: str | None`, `transport_type: str`, `booking_reference: str`, `ticket_data: dict`
  - `TripRepository` with `list_for_owner`, `get_for_owner`, `create`, `update`, `delete`, `add_stop`, `generate_legs`, `snapshot_stops`

`unique_together(trip, sequence_order)` has no Firestore equivalent, so `add_stop` runs inside a transaction that re-reads existing sequence orders and rejects duplicates.

- [ ] **Step 1: Write the failing repository tests**

Replace `backend/apps/trips/tests.py` with (endpoint tests are added in Step 5):

```python
from django.test import SimpleTestCase

from apps.common.testing import FirestoreTestMixin
from apps.trips.repositories import DuplicateSequenceOrder, TripRepository

TRIP_DATA = {
    "name": "Summer trip",
    "date": "2026-08-01",
    "start_date": "2026-08-01",
    "end_date": "2026-08-10",
    "status": "DRAFT",
}


class TripRepositoryTests(FirestoreTestMixin, SimpleTestCase):
    collections_to_purge = ["trips"]

    def setUp(self):
        super().setUp()
        self.trips = TripRepository()

    def test_create_assigns_string_id_and_owner(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsInstance(trip.id, str)
        self.assertEqual(trip.owner_key, "owner-a")

    def test_list_is_owner_scoped(self):
        self.trips.create("owner-a", TRIP_DATA)
        self.trips.create("owner-b", TRIP_DATA)
        self.assertEqual(len(self.trips.list_for_owner("owner-a")), 1)

    def test_get_for_wrong_owner_returns_none(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsNone(self.trips.get_for_owner(trip.id, "owner-b"))

    def test_dates_default_from_legacy_date_field(self):
        trip = self.trips.create("owner-a", {"name": "T", "date": "2026-09-01", "status": "DRAFT"})
        self.assertEqual(trip.start_date, "2026-09-01")
        self.assertEqual(trip.end_date, "2026-09-01")

    def test_add_stop_persists(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        stop = self.trips.add_stop(
            trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0}
        )
        self.assertEqual(stop.sequence_order, 1)

    def test_duplicate_sequence_order_rejected(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        with self.assertRaises(DuplicateSequenceOrder):
            self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 3.0, "lng": 4.0})

    def test_add_stop_for_wrong_owner_returns_none(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertIsNone(
            self.trips.add_stop(trip.id, "owner-b", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        )

    def test_generate_legs_links_consecutive_stops(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 2, "lat": 3.0, "lng": 4.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 3, "lat": 5.0, "lng": 6.0})

        legs = self.trips.generate_legs(trip.id, "owner-a")
        self.assertEqual(len(legs), 2)

    def test_generate_legs_is_idempotent(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 2, "lat": 3.0, "lng": 4.0})

        self.trips.generate_legs(trip.id, "owner-a")
        legs = self.trips.generate_legs(trip.id, "owner-a")
        self.assertEqual(len(legs), 1)

    def test_snapshot_on_draft_to_booked(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(
            trip.id,
            "owner-a",
            {"sequence_order": 1, "lat": 1.0, "lng": 2.0, "airport_id": 1},
        )
        self.trips.update(trip.id, "owner-a", {"status": "BOOKED"})

        stops = self.trips.list_stops(trip.id, "owner-a")
        self.assertTrue(stops[0].snapshot_address)
        self.assertIn("hub", stops[0].snapshot_metadata)

    def test_delete_removes_trip_and_children(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.trips.add_stop(trip.id, "owner-a", {"sequence_order": 1, "lat": 1.0, "lng": 2.0})
        self.assertTrue(self.trips.delete(trip.id, "owner-a"))
        self.assertIsNone(self.trips.get_for_owner(trip.id, "owner-a"))

    def test_delete_by_wrong_owner_refused(self):
        trip = self.trips.create("owner-a", TRIP_DATA)
        self.assertFalse(self.trips.delete(trip.id, "owner-b"))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.trips -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.trips.repositories'`

- [ ] **Step 3: Write the repository**

Create `backend/apps/trips/repositories.py`:

```python
"""Firestore repositories for Trip and its stop/leg subcollections.

Layout:
    trips/{tripId}          owner_key: str
      ├── stops/{stopId}
      └── legs/{legId}

Firestore cannot express unique_together(trip, sequence_order), so add_stop
runs in a transaction that re-reads existing orders and refuses duplicates.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

from google.cloud import firestore as gcloud_firestore

from apps.airports import reference as airport_reference
from apps.common import firestore as fs
from apps.stations import reference as station_reference

TRIPS = "trips"
STOPS = "stops"
LEGS = "legs"

STATUS_DRAFT = "DRAFT"
STATUS_BOOKED = "BOOKED"


class DuplicateSequenceOrder(Exception):
    """Raised when a stop would reuse an existing sequence_order on a trip."""


@dataclass
class TripRecord:
    id: str
    owner_key: str
    name: str = ""
    date: str | None = None
    start_date: str | None = None
    end_date: str | None = None
    status: str = STATUS_DRAFT


@dataclass
class TripStopRecord:
    id: str
    trip_id: str
    sequence_order: int = 0
    lat: float | None = None
    lng: float | None = None
    person_ids: list[str] = field(default_factory=list)
    airport_id: int | None = None
    station_id: int | None = None
    snapshot_address: str = ""
    snapshot_metadata: dict = field(default_factory=dict)


@dataclass
class TripLegRecord:
    id: str
    trip_id: str
    departure_stop_id: str = ""
    arrival_stop_id: str = ""
    departure_time: str | None = None
    arrival_time: str | None = None
    transport_type: str = "CAR"
    booking_reference: str = ""
    ticket_data: dict = field(default_factory=dict)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class TripRepository:
    def _collection(self):
        return fs.collection(TRIPS)

    def _owned_ref(self, trip_id: str, owner_key: str):
        ref = self._collection().document(trip_id)
        doc = ref.get()
        if not doc.exists or (doc.to_dict() or {}).get("owner_key") != owner_key:
            return None
        return ref

    def _hydrate(self, doc) -> TripRecord:
        data = doc.to_dict() or {}
        return TripRecord(
            id=doc.id,
            owner_key=data.get("owner_key", ""),
            name=data.get("name", ""),
            date=data.get("date"),
            start_date=data.get("start_date"),
            end_date=data.get("end_date"),
            status=data.get("status", STATUS_DRAFT),
        )

    def _hydrate_stop(self, doc, trip_id: str) -> TripStopRecord:
        data = doc.to_dict() or {}
        return TripStopRecord(
            id=doc.id,
            trip_id=trip_id,
            sequence_order=int(data.get("sequence_order", 0)),
            lat=data.get("lat"),
            lng=data.get("lng"),
            person_ids=list(data.get("person_ids", [])),
            airport_id=data.get("airport_id"),
            station_id=data.get("station_id"),
            snapshot_address=data.get("snapshot_address", ""),
            snapshot_metadata=dict(data.get("snapshot_metadata", {})),
        )

    def _hydrate_leg(self, doc, trip_id: str) -> TripLegRecord:
        data = doc.to_dict() or {}
        return TripLegRecord(
            id=doc.id,
            trip_id=trip_id,
            departure_stop_id=data.get("departure_stop_id", ""),
            arrival_stop_id=data.get("arrival_stop_id", ""),
            departure_time=data.get("departure_time"),
            arrival_time=data.get("arrival_time"),
            transport_type=data.get("transport_type", "CAR"),
            booking_reference=data.get("booking_reference", ""),
            ticket_data=dict(data.get("ticket_data", {})),
        )

    def list_for_owner(self, owner_key: str) -> list[TripRecord]:
        query = self._collection().where("owner_key", "==", owner_key)
        return [self._hydrate(doc) for doc in query.stream()]

    def get_for_owner(self, trip_id: str, owner_key: str) -> TripRecord | None:
        ref = self._owned_ref(trip_id, owner_key)
        return self._hydrate(ref.get()) if ref is not None else None

    def create(self, owner_key: str, data: dict) -> TripRecord:
        payload = {
            "owner_key": owner_key,
            "name": data.get("name", ""),
            "date": data.get("date"),
            # Sync start/end with the legacy `date` field when absent.
            "start_date": data.get("start_date") or data.get("date"),
            "end_date": data.get("end_date") or data.get("date"),
            "status": data.get("status", STATUS_DRAFT),
            "created_at": _now_iso(),
        }
        ref = self._collection().document()
        ref.set(payload)
        return self._hydrate(ref.get())

    def update(self, trip_id: str, owner_key: str, data: dict) -> TripRecord | None:
        ref = self._owned_ref(trip_id, owner_key)
        if ref is None:
            return None

        previous_status = (ref.get().to_dict() or {}).get("status", STATUS_DRAFT)
        payload = {
            k: v
            for k, v in data.items()
            if k in {"name", "date", "start_date", "end_date", "status"}
        }
        payload["updated_at"] = _now_iso()
        ref.update(payload)

        # Freeze stop snapshots on the DRAFT -> BOOKED transition.
        if previous_status == STATUS_DRAFT and payload.get("status") == STATUS_BOOKED:
            self.snapshot_stops(trip_id, owner_key)

        return self._hydrate(ref.get())

    def delete(self, trip_id: str, owner_key: str) -> bool:
        ref = self._owned_ref(trip_id, owner_key)
        if ref is None:
            return False
        for sub in (STOPS, LEGS):
            for doc in ref.collection(sub).stream():
                doc.reference.delete()
        ref.delete()
        return True

    def list_stops(self, trip_id: str, owner_key: str) -> list[TripStopRecord]:
        ref = self._owned_ref(trip_id, owner_key)
        if ref is None:
            return []
        stops = [
            self._hydrate_stop(doc, trip_id)
            for doc in ref.collection(STOPS).stream()
        ]
        stops.sort(key=lambda s: s.sequence_order)
        return stops

    def list_legs(self, trip_id: str, owner_key: str) -> list[TripLegRecord]:
        ref = self._owned_ref(trip_id, owner_key)
        if ref is None:
            return []
        return [self._hydrate_leg(doc, trip_id) for doc in ref.collection(LEGS).stream()]

    def add_stop(self, trip_id: str, owner_key: str, data: dict) -> TripStopRecord | None:
        trip_ref = self._owned_ref(trip_id, owner_key)
        if trip_ref is None:
            return None

        sequence_order = int(data.get("sequence_order", 0))
        stops_ref = trip_ref.collection(STOPS)
        new_ref = stops_ref.document()

        client = fs.get_client()

        @gcloud_firestore.transactional
        def _create(transaction):
            existing = stops_ref.where("sequence_order", "==", sequence_order).limit(1)
            if list(existing.stream(transaction=transaction)):
                raise DuplicateSequenceOrder(
                    f"sequence_order {sequence_order} already exists on trip {trip_id}"
                )
            transaction.set(
                new_ref,
                {
                    "sequence_order": sequence_order,
                    "lat": data.get("lat"),
                    "lng": data.get("lng"),
                    "person_ids": list(data.get("person_ids", [])),
                    "airport_id": data.get("airport_id"),
                    "station_id": data.get("station_id"),
                    "snapshot_address": data.get("snapshot_address", ""),
                    "snapshot_metadata": data.get("snapshot_metadata", {}),
                },
            )

        _create(client.transaction())
        self.generate_legs(trip_id, owner_key)
        return self._hydrate_stop(new_ref.get(), trip_id)

    def generate_legs(self, trip_id: str, owner_key: str) -> list[TripLegRecord]:
        """Ensure a leg exists between each consecutive pair of stops.

        Idempotent: existing pairs are left alone rather than recreated, so
        repeated calls do not duplicate legs or lose booking data.
        """
        trip_ref = self._owned_ref(trip_id, owner_key)
        if trip_ref is None:
            return []

        stops = self.list_stops(trip_id, owner_key)
        legs_ref = trip_ref.collection(LEGS)
        existing = {
            (
                (doc.to_dict() or {}).get("departure_stop_id"),
                (doc.to_dict() or {}).get("arrival_stop_id"),
            )
            for doc in legs_ref.stream()
        }

        for departure, arrival in zip(stops, stops[1:]):
            if (departure.id, arrival.id) in existing:
                continue
            legs_ref.document().set(
                {
                    "departure_stop_id": departure.id,
                    "arrival_stop_id": arrival.id,
                    "departure_time": None,
                    "arrival_time": None,
                    "transport_type": "CAR",
                    "booking_reference": "",
                    "ticket_data": {},
                }
            )

        return self.list_legs(trip_id, owner_key)

    def update_leg(
        self, trip_id: str, leg_id: str, owner_key: str, data: dict
    ) -> TripLegRecord | None:
        trip_ref = self._owned_ref(trip_id, owner_key)
        if trip_ref is None:
            return None
        leg_ref = trip_ref.collection(LEGS).document(leg_id)
        if not leg_ref.get().exists:
            return None
        leg_ref.update(data)
        return self._hydrate_leg(leg_ref.get(), trip_id)

    def snapshot_stops(self, trip_id: str, owner_key: str) -> None:
        """Freeze human-readable stop details at booking time.

        Mirrors the previous TripStop.perform_snapshot(), reading people from
        Firestore and hubs from the in-memory reference indexes.
        """
        from apps.people.repositories import PersonRepository

        trip_ref = self._owned_ref(trip_id, owner_key)
        if trip_ref is None:
            return

        people_repo = PersonRepository()
        for doc in trip_ref.collection(STOPS).stream():
            stop = self._hydrate_stop(doc, trip_id)
            metadata: dict = {"people": [], "hub": None}
            address_parts: list[str] = []

            for person_id in stop.person_ids:
                person = people_repo.get_for_owner(person_id, owner_key)
                if person is None:
                    continue
                full_name = f"{person.first_name} {person.last_name}".strip()
                metadata["people"].append({"id": person.id, "name": full_name})
                address_parts.append(
                    ", ".join(
                        filter(
                            None,
                            [
                                full_name,
                                person.street,
                                person.city,
                                person.state,
                                person.country,
                            ],
                        )
                    )
                )

            if stop.airport_id:
                airport = airport_reference.get_by_id(stop.airport_id)
                if airport is not None:
                    metadata["hub"] = {
                        "name": airport.name,
                        "code": airport.iata_code,
                        "type": "AIRPORT",
                    }
                    address_parts.append(f"{airport.name} ({airport.iata_code})")
            elif stop.station_id:
                station = station_reference.get_by_id(stop.station_id)
                if station is not None:
                    metadata["hub"] = {
                        "name": station.name,
                        "code": station.uic_ref or str(station.osm_id),
                        "type": "STATION",
                    }
                    address_parts.append(station.name)

            doc.reference.update(
                {
                    "snapshot_address": ", ".join(address_parts),
                    "snapshot_metadata": metadata,
                }
            )
```

- [ ] **Step 4: Run repository tests to verify they pass**

Run: `docker compose exec api poetry run python manage.py test apps.trips -v 2`
Expected: PASS — 12 repository tests

- [ ] **Step 5: Rewrite serializers, views, and add endpoint tests**

Replace `backend/apps/trips/serializers.py`:

```python
from rest_framework import serializers

STATUS_CHOICES = ["DRAFT", "BOOKED", "CANCELLED"]
TRANSPORT_CHOICES = ["FLIGHT", "TRAIN", "BUS", "CAR"]


class TripStopSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    sequence_order = serializers.IntegerField(min_value=0)
    lat = serializers.FloatField(required=False, allow_null=True)
    lng = serializers.FloatField(required=False, allow_null=True)
    people = serializers.ListField(
        source="person_ids", child=serializers.CharField(), required=False
    )
    airport = serializers.IntegerField(source="airport_id", required=False, allow_null=True)
    station = serializers.IntegerField(source="station_id", required=False, allow_null=True)
    snapshot_address = serializers.CharField(read_only=True, allow_blank=True)
    snapshot_metadata = serializers.DictField(read_only=True)


class TripLegSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    trip = serializers.CharField(source="trip_id", read_only=True)
    departure_stop = serializers.CharField(source="departure_stop_id", read_only=True)
    arrival_stop = serializers.CharField(source="arrival_stop_id", read_only=True)
    departure_time = serializers.DateTimeField(required=False, allow_null=True)
    arrival_time = serializers.DateTimeField(required=False, allow_null=True)
    transport_type = serializers.ChoiceField(choices=TRANSPORT_CHOICES, required=False)
    booking_reference = serializers.CharField(max_length=100, required=False, allow_blank=True)
    ticket_data = serializers.DictField(required=False)


class TripSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    name = serializers.CharField(max_length=255)
    date = serializers.DateField()
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    status = serializers.ChoiceField(choices=STATUS_CHOICES, required=False)
    user = serializers.CharField(source="owner_key", read_only=True)
```

Replace `backend/apps/trips/views.py`:

```python
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.people.views import owner_key_for

from .repositories import DuplicateSequenceOrder, TripRepository
from .serializers import TripLegSerializer, TripSerializer, TripStopSerializer
from .services import OSRMService, RoutingError, TransportLookupService


class TripViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @property
    def repository(self):
        return TripRepository()

    def list(self, request):
        trips = self.repository.list_for_owner(owner_key_for(request))
        return Response(TripSerializer(trips, many=True).data)

    def retrieve(self, request, pk=None):
        trip = self.repository.get_for_owner(pk, owner_key_for(request))
        if trip is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(TripSerializer(trip).data)

    def create(self, request):
        serializer = TripSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = {
            k: (v.isoformat() if hasattr(v, 'isoformat') else v)
            for k, v in serializer.validated_data.items()
        }
        trip = self.repository.create(owner_key_for(request), payload)
        return Response(TripSerializer(trip).data, status=status.HTTP_201_CREATED)

    def update(self, request, pk=None):
        return self._write_update(request, pk, partial=False)

    def partial_update(self, request, pk=None):
        return self._write_update(request, pk, partial=True)

    def _write_update(self, request, pk, partial):
        serializer = TripSerializer(data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        payload = {
            k: (v.isoformat() if hasattr(v, 'isoformat') else v)
            for k, v in serializer.validated_data.items()
        }
        trip = self.repository.update(pk, owner_key_for(request), payload)
        if trip is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(TripSerializer(trip).data)

    def destroy(self, request, pk=None):
        if not self.repository.delete(pk, owner_key_for(request)):
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['get', 'post'], url_path='stops')
    def stops(self, request, pk=None):
        owner_key = owner_key_for(request)
        if request.method == 'GET':
            return Response(
                TripStopSerializer(self.repository.list_stops(pk, owner_key), many=True).data
            )

        serializer = TripStopSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            stop = self.repository.add_stop(pk, owner_key, dict(serializer.validated_data))
        except DuplicateSequenceOrder as exc:
            return Response({'sequence_order': [str(exc)]}, status=status.HTTP_400_BAD_REQUEST)
        if stop is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(TripStopSerializer(stop).data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def calculate_route(self, request):
        coordinates = request.data.get('coordinates')

        if not coordinates or not isinstance(coordinates, list):
            return Response(
                {'error': 'Missing or invalid "coordinates" in payload. Expected a list of [lon, lat].'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Validate structure: list of lists with 2 numeric values
        for coord in coordinates:
            if not isinstance(coord, list) or len(coord) != 2:
                return Response(
                    {'error': 'Each coordinate must be a list of two numbers: [longitude, latitude].'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            try:
                float(coord[0])
                float(coord[1])
            except (ValueError, TypeError):
                return Response(
                    {'error': 'Coordinates must be numeric values.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        try:
            geometry = OSRMService.get_route(coordinates)
            return Response(geometry, status=status.HTTP_200_OK)
        except RoutingError as e:
            return Response({'error': str(e)}, status=e.status_code)


class TripLegViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @property
    def repository(self):
        return TripRepository()

    def list(self, request):
        owner_key = owner_key_for(request)
        legs = []
        for trip in self.repository.list_for_owner(owner_key):
            legs.extend(self.repository.list_legs(trip.id, owner_key))
        return Response(TripLegSerializer(legs, many=True).data)

    def _find_leg(self, leg_id, owner_key):
        for trip in self.repository.list_for_owner(owner_key):
            for leg in self.repository.list_legs(trip.id, owner_key):
                if leg.id == leg_id:
                    return leg
        return None

    def retrieve(self, request, pk=None):
        leg = self._find_leg(pk, owner_key_for(request))
        if leg is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return Response(TripLegSerializer(leg).data)

    def partial_update(self, request, pk=None):
        owner_key = owner_key_for(request)
        leg = self._find_leg(pk, owner_key)
        if leg is None:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = TripLegSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        payload = {
            k: (v.isoformat() if hasattr(v, 'isoformat') else v)
            for k, v in serializer.validated_data.items()
        }
        updated = self.repository.update_leg(leg.trip_id, pk, owner_key, payload)
        return Response(TripLegSerializer(updated).data)

    @action(detail=True, methods=['post'])
    def smart_lookup(self, request, pk=None):
        owner_key = owner_key_for(request)
        leg = self._find_leg(pk, owner_key)
        if leg is None:
            return Response(status=status.HTTP_404_NOT_FOUND)

        identifier = request.data.get('identifier', leg.booking_reference)
        if not identifier:
            return Response({'error': 'Missing identifier'}, status=status.HTTP_400_BAD_REQUEST)

        data = {}
        if leg.transport_type == 'FLIGHT':
            data = TransportLookupService.lookup_flight(identifier)
        elif leg.transport_type == 'TRAIN':
            data = TransportLookupService.lookup_train(identifier)

        if data:
            ticket_data = dict(leg.ticket_data)
            ticket_data.update(data)
            payload = {'ticket_data': ticket_data}
            if 'departure' in data and 'time' in data['departure']:
                payload['departure_time'] = data['departure']['time']
            if 'arrival' in data and 'time' in data['arrival']:
                payload['arrival_time'] = data['arrival']['time']

            updated = self.repository.update_leg(leg.trip_id, pk, owner_key, payload)
            return Response(TripLegSerializer(updated).data)

        return Response(
            {'message': 'No data found for this identifier'},
            status=status.HTTP_404_NOT_FOUND,
        )
```

Delete models/migrations and empty the admin:

```bash
git rm backend/apps/trips/models.py
git rm -r backend/apps/trips/migrations
```

Replace `backend/apps/trips/admin.py` with:

```python
# Trips, stops and legs live in Firestore, not the ORM. Inspect them through
# the emulator UI (http://localhost:4000) locally, or the Firestore Console.
```

Append endpoint tests to `backend/apps/trips/tests.py`:

```python
from django.contrib.auth.models import User
from rest_framework.test import APITestCase


class TripEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["trips"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")
        self.other = User.objects.create_user(username="owner-b", password="pw12345!")
        self.client.force_authenticate(user=self.user)

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.get("/api/trips/").status_code, 401)

    def test_create_and_list(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.assertEqual(created.status_code, 201)
        self.assertEqual(len(self.client.get("/api/trips/").data), 1)

    def test_trip_data_isolation(self):
        self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.client.force_authenticate(user=self.other)
        self.assertEqual(len(self.client.get("/api/trips/").data), 0)

    def test_cannot_retrieve_another_owners_trip(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        self.client.force_authenticate(user=self.other)
        response = self.client.get(f"/api/trips/{created.data['id']}/")
        self.assertEqual(response.status_code, 404)

    def test_duplicate_sequence_order_returns_400(self):
        created = self.client.post("/api/trips/", TRIP_DATA, format="json")
        trip_id = created.data["id"]
        stop = {"sequence_order": 1, "lat": 1.0, "lng": 2.0}
        self.client.post(f"/api/trips/{trip_id}/stops/", stop, format="json")
        second = self.client.post(f"/api/trips/{trip_id}/stops/", stop, format="json")
        self.assertEqual(second.status_code, 400)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `docker compose exec api poetry run python manage.py test apps.trips -v 2`
Expected: PASS — repository and endpoint tests

- [ ] **Step 7: Commit**

```bash
git add backend/apps/trips
git commit -m "refactor(trips): move Trip, TripStop and TripLeg onto Firestore repositories"
```

---

### Task 14: UserProfile repository and API

**Files:**
- Create: `backend/apps/users/repositories.py`
- Modify: `backend/apps/users/models.py` (remove `UserProfile` + signals), `backend/apps/users/serializers.py`, `backend/apps/users/views.py`, `backend/apps/users/admin.py`
- Create: `backend/apps/users/migrations/0002_remove_userprofile.py`
- Test: `backend/apps/users/tests.py` (extend)

**Interfaces:**
- Consumes: `apps.common.firestore`, `apps.common.storage`
- Produces: `UserProfileRecord`, `UserProfileRepository.get_or_create(owner_key)`, `UserProfileRepository.update(owner_key, data)`

`user_profiles` uses the owner key as the document ID, so no query or ownership filter is needed — the key *is* the scope.

- [ ] **Step 1: Write the failing test**

Replace `backend/apps/users/tests.py` additions — append:

```python
from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from apps.common.testing import FirestoreTestMixin
from apps.users.repositories import UserProfileRepository


class UserProfileRepositoryTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["user_profiles"]

    def test_get_or_create_is_idempotent(self):
        repo = UserProfileRepository()
        first = repo.get_or_create("owner-a")
        second = repo.get_or_create("owner-a")
        self.assertEqual(first.owner_key, second.owner_key)

    def test_defaults_applied(self):
        profile = UserProfileRepository().get_or_create("owner-a")
        self.assertEqual(profile.pin_color, "#2196F3")
        self.assertEqual(profile.distance_unit, "metric")

    def test_update_persists(self):
        repo = UserProfileRepository()
        repo.get_or_create("owner-a")
        updated = repo.update("owner-a", {"city": "Chicago", "distance_unit": "imperial"})
        self.assertEqual(updated.city, "Chicago")
        self.assertEqual(updated.distance_unit, "imperial")

    def test_profiles_are_isolated_by_key(self):
        repo = UserProfileRepository()
        repo.update("owner-a", {"city": "Chicago"})
        self.assertEqual(repo.get_or_create("owner-b").city, "")


class UserProfileEndpointTests(FirestoreTestMixin, APITestCase):
    collections_to_purge = ["user_profiles"]

    def setUp(self):
        super().setUp()
        self.user = User.objects.create_user(username="owner-a", password="pw12345!")

    def test_requires_authentication(self):
        self.assertEqual(self.client.get("/api/user/profile/").status_code, 401)

    def test_get_creates_profile_lazily(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.get("/api/user/profile/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["pin_color"], "#2196F3")

    def test_patch_updates_profile(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.patch(
            "/api/user/profile/", {"city": "Chicago"}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["city"], "Chicago")
```

Confirm the profile route path first: `docker compose exec api poetry run python manage.py show_urls 2>/dev/null || cat backend/apps/users/urls.py`. Adjust `/api/user/profile/` in the tests above to match the registered path.

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec api poetry run python manage.py test apps.users -v 2`
Expected: FAIL — `ModuleNotFoundError: No module named 'apps.users.repositories'`

- [ ] **Step 3: Write the repository**

Create `backend/apps/users/repositories.py`:

```python
"""Firestore repository for user profiles.

The document ID is the owner key, so scoping is inherent — there is no query
to forget an ownership filter on.

    user_profiles/{ownerKey}
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, fields

from apps.common import firestore as fs

USER_PROFILES = "user_profiles"


@dataclass
class UserProfileRecord:
    owner_key: str
    profile_image: str | None = None
    city: str = ""
    state: str = ""
    country: str = ""
    street: str = ""
    birth_date: str | None = None
    phone_number: str = ""
    pin_color: str = "#2196F3"
    pin_style: str = "teardrop"
    pin_icon_type: str = "none"
    pin_emoji: str | None = None
    distance_unit: str = "metric"


_EDITABLE = {f.name for f in fields(UserProfileRecord)} - {"owner_key"}


class UserProfileRepository:
    def _document(self, owner_key: str):
        return fs.collection(USER_PROFILES).document(owner_key)

    def _hydrate(self, owner_key: str, data: dict) -> UserProfileRecord:
        return UserProfileRecord(
            owner_key=owner_key,
            **{k: v for k, v in data.items() if k in _EDITABLE},
        )

    def get_or_create(self, owner_key: str) -> UserProfileRecord:
        ref = self._document(owner_key)
        doc = ref.get()
        if doc.exists:
            return self._hydrate(owner_key, doc.to_dict() or {})

        record = UserProfileRecord(owner_key=owner_key)
        payload = asdict(record)
        payload.pop("owner_key")
        ref.set(payload)
        return record

    def update(self, owner_key: str, data: dict) -> UserProfileRecord:
        self.get_or_create(owner_key)
        payload = {k: v for k, v in data.items() if k in _EDITABLE}
        ref = self._document(owner_key)
        ref.update(payload)
        return self._hydrate(owner_key, ref.get().to_dict() or {})
```

- [ ] **Step 4: Remove the ORM model and rewrite the API layer**

Replace `backend/apps/users/models.py` entirely:

```python
# UserProfile now lives in Firestore (see repositories.py). The post_save
# signals that auto-created it are gone with it: profile creation is lazy,
# handled by UserProfileRepository.get_or_create on first read.
#
# django.contrib.auth.User remains until ClickUp 86bb3eu64 (Auth0 -> GCIP)
# removes the need for a relational identity table.
```

Create `backend/apps/users/migrations/0002_remove_userprofile.py`:

```python
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0001_initial'),
    ]

    operations = [
        migrations.DeleteModel(name='UserProfile'),
    ]
```

Verify the initial migration's real name first with `ls backend/apps/users/migrations/` and adjust the dependency if it differs.

Replace the `UserProfileSerializer` in `backend/apps/users/serializers.py` with a plain serializer, leaving `RegisterSerializer` and the password-reset serializers untouched (they still use Django `User` until task 86bb3eu64):

```python
class UserProfileSerializer(serializers.Serializer):
    profile_image = serializers.SerializerMethodField()
    city = serializers.CharField(max_length=100, required=False, allow_blank=True)
    state = serializers.CharField(max_length=100, required=False, allow_blank=True)
    country = serializers.CharField(max_length=100, required=False, allow_blank=True)
    street = serializers.CharField(max_length=255, required=False, allow_blank=True)
    birth_date = serializers.DateField(required=False, allow_null=True)
    phone_number = serializers.CharField(required=False, allow_blank=True)
    pin_color = serializers.CharField(max_length=7, required=False)
    pin_style = serializers.ChoiceField(
        choices=["teardrop", "circle", "square", "triangle", "diamond"], required=False
    )
    pin_icon_type = serializers.ChoiceField(
        choices=["none", "emoji", "initials", "picture"], required=False
    )
    pin_emoji = serializers.CharField(
        max_length=10, required=False, allow_null=True, allow_blank=True
    )
    distance_unit = serializers.ChoiceField(choices=["metric", "imperial"], required=False)

    def get_profile_image(self, obj):
        from apps.common.storage import upload_url

        return upload_url(getattr(obj, "profile_image", None), self.context.get("request"))
```

Replace the `UserProfileView` class in `backend/apps/users/views.py` (leave the register and password-reset views as they are):

```python
class UserProfileView(APIView):
    """Get and update the current user's profile.

    Supports image upload via multipart form data.
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @property
    def repository(self):
        from .repositories import UserProfileRepository

        return UserProfileRepository()

    def get(self, request):
        profile = self.repository.get_or_create(request.user.username)
        return Response(UserProfileSerializer(profile, context={'request': request}).data)

    def patch(self, request):
        serializer = UserProfileSerializer(
            data=request.data, partial=True, context={'request': request}
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        payload = dict(serializer.validated_data)
        birth_date = payload.get('birth_date')
        if birth_date is not None:
            payload['birth_date'] = birth_date.isoformat()

        uploaded = request.FILES.get('profile_image')
        if uploaded is not None:
            from apps.common.storage import save_upload

            payload['profile_image'] = save_upload(uploaded, prefix='user_profiles')

        profile = self.repository.update(request.user.username, payload)
        return Response(UserProfileSerializer(profile, context={'request': request}).data)
```

Remove the `from .models import UserProfile` import from `views.py`, and replace `backend/apps/users/admin.py` with:

```python
# UserProfile lives in Firestore, not the ORM. Django admin retains only the
# built-in User and Group models until ClickUp 86bb3eu64 removes the need for
# a relational identity table.
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `docker compose exec api poetry run python manage.py test apps.users -v 2`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/apps/users
git commit -m "refactor(users): move UserProfile to Firestore, drop model and signals"
```

---

### Task 15: Drop PostGIS, switch to SQLite, seed command

**Files:**
- Modify: `backend/config/settings.py`, `backend/pyproject.toml`, `backend/Dockerfile`, `Makefile`, `docker-compose.prod.yml`
- Create: `backend/apps/common/management/commands/seed.py` (+ `management/__init__.py`, `management/commands/__init__.py`)
- Test: `backend/tests/test_api_security.py` (adapt setup only, never assertions)

**Interfaces:**
- Consumes: all repositories
- Produces: `make seed` populating the emulator

- [ ] **Step 1: Switch the database to SQLite and drop GIS apps**

Modify `backend/config/settings.py`:

Replace the `DATABASES` block with:

```python
# Django's own tables only (auth, admin, sessions, contenttypes). Application
# data lives in Firestore. Ephemeral on Cloud Run — ClickUp 86bb3eu64
# (Auth0 -> GCIP) removes the need for this entirely.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'django_internal.sqlite3',
    }
}
```

Remove the `import dj_database_url` line. Remove `'django.contrib.gis',` and `'rest_framework_gis',` from `INSTALLED_APPS`.

- [ ] **Step 2: Trim dependencies and the Docker image**

Modify `backend/pyproject.toml` — remove these three lines from `dependencies`:

```toml
    "psycopg2-binary (>=2.9.11,<3.0.0)",
    "djangorestframework-gis (>=1.2.0,<2.0.0)",
    "dj-database-url (>=2.1.0,<3.0.0)",
```

Replace the system-dependency stanza in `backend/Dockerfile` (steps 1 and 2 of that file) with:

```dockerfile
# 1. Install System Dependencies
# - build-essential, python3-dev: required for Python 3.14 to compile wheels
# - gettext: required for Django makemessages
# GDAL/PROJ/PostGIS dependencies were removed with the PostGIS migration —
# reference geodata is now an in-memory index (see apps/*/reference.py).
RUN apt-get update && apt-get install -y \
    build-essential \
    python3-dev \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# 2. Set Environment Variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```

- [ ] **Step 3: Write the seed command**

Create `backend/apps/common/management/__init__.py` and `backend/apps/common/management/commands/__init__.py` (both empty), then `backend/apps/common/management/commands/seed.py`:

```python
"""Populate the Firestore emulator with representative sample data.

There is no production data to migrate, so local development seeds rather than
imports. Refuses to run against a real Firestore instance.
"""

import os

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError

from apps.people.repositories import ContactLogRepository, PersonRepository
from apps.trips.repositories import TripRepository
from apps.users.repositories import UserProfileRepository

DEMO_USERNAME = "demo"

SAMPLE_PEOPLE = [
    {
        "tag": "FRIEND", "first_name": "Ada", "last_name": "Lovelace",
        "city": "London", "state": "England", "country": "UK",
        "lat": 51.5074, "lng": -0.1278, "timezone": "Europe/London",
        "pin_color": "#F44336", "contact_cadence_days": 30,
    },
    {
        "tag": "FAMILY", "first_name": "Grace", "last_name": "Hopper",
        "city": "New York", "state": "NY", "country": "USA",
        "lat": 40.7128, "lng": -74.0060, "timezone": "America/New_York",
        "pin_color": "#2196F3", "contact_cadence_days": 14,
    },
    {
        "tag": "FRIEND", "first_name": "Alan", "last_name": "Turing",
        "city": "Chicago", "state": "IL", "country": "USA",
        "lat": 41.8781, "lng": -87.6298, "timezone": "America/Chicago",
        "pin_color": "#4CAF50", "contact_cadence_days": 60,
    },
]


class Command(BaseCommand):
    help = "Seed the Firestore emulator with sample data."

    def handle(self, *args, **options):
        if not os.environ.get("FIRESTORE_EMULATOR_HOST"):
            raise CommandError(
                "FIRESTORE_EMULATOR_HOST is not set. Refusing to seed what may be "
                "a real Firestore database. Start the emulator with `make up`."
            )

        user, created = User.objects.get_or_create(
            username=DEMO_USERNAME,
            defaults={"email": "demo@example.com"},
        )
        if created:
            user.set_password("demo12345!")
            user.save()
            self.stdout.write(f"Created Django user '{DEMO_USERNAME}' (password: demo12345!)")

        owner_key = user.username
        people_repo = PersonRepository()
        logs_repo = ContactLogRepository()

        UserProfileRepository().get_or_create(owner_key)

        created_people = []
        for data in SAMPLE_PEOPLE:
            person = people_repo.create(owner_key, data)
            created_people.append(person)
            self.stdout.write(f"  person: {person.first_name} {person.last_name}")

        logs_repo.create(
            owner_key, created_people[0].id,
            {"channel": "CALL", "contacted_at": "2026-07-10T18:00:00+00:00", "note": "Caught up"},
        )
        logs_repo.create(
            owner_key, created_people[1].id,
            {"channel": "VIDEO", "contacted_at": "2026-07-20T15:30:00+00:00", "note": None},
        )

        trip = TripRepository().create(
            owner_key,
            {
                "name": "Summer visit", "date": "2026-08-01",
                "start_date": "2026-08-01", "end_date": "2026-08-10",
                "status": "DRAFT",
            },
        )
        self.stdout.write(f"  trip: {trip.name}")

        self.stdout.write(self.style.SUCCESS("Seed complete."))
```

- [ ] **Step 4: Update the Makefile**

Modify `Makefile` — replace the `mig` target and add `seed`:

```make
mig:
	docker compose exec api poetry run python manage.py migrate

seed:
	docker compose exec api poetry run python manage.py seed

fetch-data:
	docker compose exec api poetry run python manage.py fetch_airports
	docker compose exec api poetry run python manage.py fetch_stations
```

`makemigrations` is deliberately dropped from `mig` — only Django's own apps have migrations now, and they ship with the framework.

- [ ] **Step 5: Adapt the security test setup**

`backend/tests/test_api_security.py` creates `Person` and `Trip` via the ORM in `setUp`. Replace only those construction calls with repository calls — for example, replace `Person.objects.create(owner=self.user_a, ...)` with:

```python
from apps.people.repositories import PersonRepository

PersonRepository().create(self.user_a.username, {
    "tag": "FRIEND", "first_name": "A", "last_name": "Person",
    "city": "Chicago", "state": "IL", "country": "USA",
    "lat": 41.8781, "lng": -87.6298,
})
```

Add `FirestoreTestMixin` to each test class that touches Firestore data. **Change no assertion.** If an assertion fails, the implementation is wrong, not the test.

The `SecurityBehaviorTests.test_registration_throttling` and `JWTAuthTests` classes need no changes — they exercise Django `User`, which is still relational.

- [ ] **Step 6: Rebuild and run the entire suite**

```bash
docker compose down -v
docker compose build
docker compose up -d
docker compose exec api poetry run python manage.py migrate
docker compose exec api poetry run python manage.py test 2>&1 | tail -30
```
Expected: PASS, with **zero** failures. `tests/test_api_security.py` assertions must be unchanged from `git show e81891d`.

- [ ] **Step 7: Verify the PostGIS removal is complete**

```bash
grep -rn "contrib.gis\|rest_framework_gis\|postgis\|psycopg2\|GEOSGeometry\|PointField" \
  backend/apps backend/config backend/tests docker-compose.yml backend/Dockerfile backend/pyproject.toml
```
Expected: no matches.

- [ ] **Step 8: Commit**

```bash
git add backend Makefile docker-compose.prod.yml
git commit -m "refactor(backend): drop PostGIS for SQLite internals, add emulator seed command"
```

---

### Task 16: Flutter string-ID compatibility

**Files:**
- Modify: `frontend/lib/models/trip.dart:178`, `frontend/lib/models/trip.dart:264`

**Interfaces:**
- Consumes: the trips API from Task 13
- Produces: nothing downstream

Firestore document IDs are strings. `Person`, `ContactLog` and `Trip` already parse defensively; `TripLeg` and `TripStop` do not.

- [ ] **Step 1: Verify the current casts**

Run: `grep -n "json\['id'\]" frontend/lib/models/trip.dart`
Expected: line 95 `json['id']?.toString()`, line 178 `json['id'] as int?`, line 264 `json['id'] as int?`

- [ ] **Step 2: Change the field types and casts**

In `frontend/lib/models/trip.dart`, change `TripLeg.id` and `TripStop.id` from `final int? id;` to `final String? id;` (lines 124 and 207), and change both `fromJson` casts:

```dart
      id: json['id']?.toString(),
```

Also update `TripStop.departureStopId` / `arrivalStopId` references on `TripLeg` (lines 125-126) from `final int departureStopId;` / `final int arrivalStopId;` to `final String departureStopId;` / `final String arrivalStopId;`, and their `fromJson` parsing to `.toString()`. `sequenceOrder` stays `int` — it is an ordering value, not a document ID.

- [ ] **Step 3: Analyze for type errors**

Run: `cd frontend && flutter analyze`
Expected: no errors. Any reported error points at another site comparing or assigning these IDs as `int`; fix each to `String`.

- [ ] **Step 4: Run the Flutter tests**

Run: `cd frontend && flutter test`
Expected: PASS

- [ ] **Step 5: Manual end-to-end verification**

```bash
make up          # Django + Firestore emulator
make seed        # sample data
cd frontend && flutter run -d chrome
```
Verify: map pins render for the three seeded people, the Pulse tab shows recency colouring, and a trip can be opened. Emulator UI at `http://localhost:4000` should show the `people`, `trips` and `user_profiles` collections.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/models/trip.dart
git commit -m "fix(frontend): accept string document IDs for TripStop and TripLeg"
```

---

## Plan Self-Review

**Spec coverage:**

| Spec section | Task(s) |
|---|---|
| §3.1 repository layer | 11, 13, 14 |
| §3.2 dependency/image changes | 8 (add), 15 (remove) |
| §4 collection layout | 11, 13, 14 |
| §4.1 field mapping | 11, 13, 14 |
| §4.1.1 removed ORM machinery (admin, signals, geocoding) | 7, 10, 12, 13, 14 |
| §4.2 document IDs | 11, 16 |
| §4.3 GeoJSON contract | 6, 7, 12 |
| §4.4 ownership validation | 11 (repository), 12 (400 response) |
| §4.5 composite indexes | 8 |
| §5 in-memory reference index | 2, 5, 7 |
| §5.1 data pipelines | 3, 4 |
| §6 emulator + Makefile + seeding | 8, 15 |
| §7 storage abstraction | 9 |
| §10 error handling | 8 (exception handler), 13 (DuplicateSequenceOrder) |
| §11 testing strategy | every task; §15 step 5 covers the security suite |
| §12 success criteria | 15 steps 6-7, 16 step 5 |

**Known follow-ups deliberately left to task 86bb3eu64:** SQLite durability on Cloud Run, Auth emulator activation, retiring `RegisterView` / password-reset views.

**Type consistency checked:** `owner_key` is `str | None` for people (public people allowed) and `str` for trips and profiles. Reference `get_nearby` returns dataclasses carrying `distance_km`. Stop and leg IDs are `str` end-to-end, matching Task 16. `contacted_at` is stored and compared as an ISO-8601 string throughout, so lexicographic ordering matches chronological ordering.

**Two defects found and fixed during review:** Task 13 used a non-existent `client.transactional` attribute (corrected to the `@gcloud_firestore.transactional` decorator, with the import added), and a stray non-ASCII character in the `snapshot_stops` docstring.

---

## Execution

Run `make up` before any task from Phase 2 onward — tests in Tasks 8 and later require the Firestore emulator.
