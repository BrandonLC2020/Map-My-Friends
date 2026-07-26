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

    def test_many_true_returns_feature_collection(self):
        things = [_Thing("a", "A", 1.0, 2.0), _Thing("b", "B", 3.0, 4.0)]
        data = ThingSerializer(things, many=True).data
        # rest_framework_gis wrapped many=True in a FeatureCollection and the
        # Flutter client reads data['features']; a bare list breaks it.
        self.assertEqual(data["type"], "FeatureCollection")
        self.assertEqual(len(data["features"]), 2)
        self.assertTrue(all(f["type"] == "Feature" for f in data["features"]))
