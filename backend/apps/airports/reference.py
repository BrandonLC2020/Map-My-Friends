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
