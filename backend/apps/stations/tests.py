from django.test import TestCase
from django.contrib.gis.geos import Point
from .models import Station

class StationModelTests(TestCase):
    def setUp(self):
        # Union Station Chicago
        self.union = Station.objects.create(
            name="Union Station",
            osm_id=12345,
            station_type="major_station",
            city="Chicago",
            country="US",
            location=Point(-87.6403, 41.8787, srid=4326)
        )
        # Ogilvie Transportation Center
        self.ogilvie = Station.objects.create(
            name="Ogilvie Transportation Center",
            osm_id=67890,
            station_type="major_station",
            city="Chicago",
            country="US",
            location=Point(-87.6391, 41.8823, srid=4326)
        )

    def test_station_creation(self):
        station = Station.objects.get(osm_id=12345)
        self.assertEqual(station.name, "Union Station")

    def test_get_nearby(self):
        # Point near Union Station
        test_point = Point(-87.6400, 41.8780, srid=4326)
        
        nearby = Station.get_nearby(test_point)
        self.assertEqual(nearby[0].osm_id, 12345) # Union Station is closer
        self.assertEqual(nearby[1].osm_id, 67890)
