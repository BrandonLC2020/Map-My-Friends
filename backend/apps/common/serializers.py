"""GeoJSON Feature envelope, replacing rest_framework_gis.

The exact output shape is load-bearing: frontend/lib/models/person.dart
parses it via Person.fromGeoJson, reading coordinates as [lng, lat]. A shape
mismatch fails silently (pins vanish) rather than raising, so this is covered
by explicit tests.
"""

from __future__ import annotations

from rest_framework import serializers


class GeoFeatureListSerializer(serializers.ListSerializer):
    """Wraps many=True output in a GeoJSON FeatureCollection.

    rest_framework_gis's GeoFeatureModelSerializer did this, and the Flutter
    client depends on it in three places: api_service.dart reads
    data['features'] for people, nearest airports and nearest stations. A bare
    list breaks the airport/station calls outright, and silently degrades the
    people call to its flat-JSON fallback, which finds no coordinates and
    drops every pin from the map.
    """

    def to_representation(self, data):
        return {
            "type": "FeatureCollection",
            "features": super().to_representation(data),
        }

    @property
    def data(self):
        # ListSerializer.data coerces its result into a ReturnList, which would
        # turn the FeatureCollection dict into a list of its keys. Skip that
        # override and go straight to BaseSerializer.data, then wrap as a dict.
        # This is the same approach rest_framework_gis used.
        return serializers.ReturnDict(
            super(serializers.ListSerializer, self).data, serializer=self
        )


class GeoFeatureSerializer(serializers.Serializer):
    """Serializer emitting {id, type, geometry, properties}.

    Subclasses declare ordinary fields including `id`, `lat` and `lng`. Those
    three are lifted out of `properties` into the envelope. With many=True the
    features are wrapped in a FeatureCollection (see GeoFeatureListSerializer).
    """

    lat_field = "lat"
    lng_field = "lng"
    id_field = "id"

    class Meta:
        list_serializer_class = GeoFeatureListSerializer

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
