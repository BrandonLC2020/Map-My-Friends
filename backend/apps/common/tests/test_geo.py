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
