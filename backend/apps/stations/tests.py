from django.test import TestCase
from django.contrib.gis.geos import Point
from rest_framework.test import APIClient
from django.contrib.auth.models import User
from .models import Station

class StationApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='testuser', password='password123')
        self.client.force_authenticate(user=self.user)
        
        # Create major station
        Station.objects.create(
            name="Major Station",
            osm_id=1,
            station_type='major_station',
            location=Point(-87.6244212, 41.8755616, srid=4326) # Chicago
        )
        # Create regional station
        Station.objects.create(
            name="Regional Station",
            osm_id=2,
            station_type='regional_station',
            location=Point(-87.6403, 41.8786, srid=4326) # Also Chicago but slightly different
        )

        # Create subway station
        Station.objects.create(
            name="Subway Station",
            osm_id=3,
            station_type='subway_station',
            location=Point(-87.6278, 41.8821, srid=4326)
        )
        # Create commuter rail station
        Station.objects.create(
            name="Commuter Rail Station",
            osm_id=4,
            station_type='commuter_rail_station',
            location=Point(-87.6333, 41.8753, srid=4326)
        )

    def test_nearest_stations_all(self):
        # Chicago center approx
        response = self.client.get('/api/stations/nearest/', {'lat': 41.87, 'lon': -87.62, 'count': 5})
        self.assertEqual(response.status_code, 200)
        # Should return all since no filter is applied
        self.assertEqual(len(response.data['features']), 4)

    def test_nearest_stations_subway_filter(self):
        response = self.client.get('/api/stations/nearest/', {
            'lat': 41.87, 
            'lon': -87.62, 
            'count': 5,
            'station_type': 'subway_station'
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['features']), 1)
        self.assertEqual(response.data['features'][0]['properties']['name'], "Subway Station")

    def test_nearest_stations_commuter_filter(self):
        response = self.client.get('/api/stations/nearest/', {
            'lat': 41.87, 
            'lon': -87.62, 
            'count': 5,
            'station_type': 'commuter_rail_station'
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['features']), 1)
        self.assertEqual(response.data['features'][0]['properties']['name'], "Commuter Rail Station")

    def test_nearest_stations_major_filter(self):
        response = self.client.get('/api/stations/nearest/', {
            'lat': 41.87, 
            'lon': -87.62, 
            'count': 5,
            'station_type': 'major_station'
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['features']), 1)
        self.assertEqual(response.data['features'][0]['properties']['name'], "Major Station")

    def test_nearest_stations_regional_filter(self):
        response = self.client.get('/api/stations/nearest/', {
            'lat': 41.87, 
            'lon': -87.62, 
            'count': 5,
            'station_type': 'regional_station'
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['features']), 1)
        self.assertEqual(response.data['features'][0]['properties']['name'], "Regional Station")
