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
