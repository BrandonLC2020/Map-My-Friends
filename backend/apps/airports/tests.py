from django.test import TestCase
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D
from .models import Airport

class AirportModelTests(TestCase):
    def setUp(self):
        # Create some test airports
        # Chicago O'Hare
        self.ord = Airport.objects.create(
            name="O'Hare International Airport",
            iata_code="ORD",
            airport_type="large_airport",
            city="Chicago",
            country="US",
            location=Point(-87.9073, 41.9742, srid=4326)
        )
        # Chicago Midway
        self.mdw = Airport.objects.create(
            name="Midway International Airport",
            iata_code="MDW",
            airport_type="large_airport",
            city="Chicago",
            country="US",
            location=Point(-87.7524, 41.7868, srid=4326)
        )
        # New York JFK
        self.jfk = Airport.objects.create(
            name="John F. Kennedy International Airport",
            iata_code="JFK",
            airport_type="large_airport",
            city="New York",
            country="US",
            location=Point(-73.7781, 40.6413, srid=4326)
        )

    def test_airport_creation(self):
        airport = Airport.objects.get(iata_code="ORD")
        self.assertEqual(airport.name, "O'Hare International Airport")
        self.assertEqual(airport.city, "Chicago")

    def test_get_nearby_sorting(self):
        # Point in downtown Chicago
        downtown_chicago = Point(-87.6298, 41.8781, srid=4326)
        
        nearby = Airport.get_nearby(downtown_chicago)
        
        # Midway is closer to downtown than O'Hare
        self.assertEqual(nearby[0].iata_code, "MDW")
        self.assertEqual(nearby[1].iata_code, "ORD")
        self.assertEqual(nearby[2].iata_code, "JFK")

    def test_get_nearby_radius(self):
        # Point in downtown Chicago
        downtown_chicago = Point(-87.6298, 41.8781, srid=4326)
        
        # O'Hare is about 25km from downtown, Midway about 15km
        # JFK is ~1100km away
        
        nearby_50km = Airport.get_nearby(downtown_chicago, radius_km=50)
        self.assertEqual(len(nearby_50km), 2)
        self.assertIn(self.ord, nearby_50km)
        self.assertIn(self.mdw, nearby_50km)
        
        nearby_20km = Airport.get_nearby(downtown_chicago, radius_km=20)
        self.assertEqual(len(nearby_20km), 1)
        self.assertEqual(nearby_20km[0], self.mdw)

    def test_distance_annotation(self):
        downtown_chicago = Point(-87.6298, 41.8781, srid=4326)
        airport = Airport.get_nearby(downtown_chicago)[0]
        
        self.assertTrue(hasattr(airport, 'distance'))
        # Distance should be around 14-16km for Midway
        self.assertGreater(airport.distance.km, 10)
        self.assertLess(airport.distance.km, 20)
