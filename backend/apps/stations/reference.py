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
