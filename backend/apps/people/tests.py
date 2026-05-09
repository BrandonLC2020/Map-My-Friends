from django.test import TestCase
from django.contrib.gis.geos import Point
from django.core.exceptions import ValidationError
from unittest.mock import patch, MagicMock
from .models import Person
from geopy.exc import GeocoderTimedOut, GeocoderServiceError

class PersonModelTests(TestCase):
    @patch('geopy.geocoders.Nominatim.geocode')
    def test_geocoding_success(self, mock_geocode):
        # Mock successful geocode response
        mock_location = MagicMock()
        mock_location.latitude = 41.8781
        mock_location.longitude = -87.6298
        mock_geocode.return_value = mock_location

        person = Person(
            first_name="Test",
            last_name="User",
            city="Chicago",
            state="IL",
            country="USA"
        )
        person.save()

        self.assertIsNotNone(person.location)
        self.assertEqual(person.location.x, -87.6298)
        self.assertEqual(person.location.y, 41.8781)
        self.assertIsNotNone(person.timezone)
        self.assertEqual(person.timezone, 'America/Chicago')
        
        # Verify geocode was called with correct parameters
        mock_geocode.assert_called_once()
        args, kwargs = mock_geocode.call_args
        self.assertEqual(args[0]['city'], 'Chicago')

    @patch('geopy.geocoders.Nominatim.geocode')
    def test_geocoding_retry_on_timeout(self, mock_geocode):
        # Mock timeout then success
        mock_location = MagicMock()
        mock_location.latitude = 40.7128
        mock_location.longitude = -74.0060
        
        mock_geocode.side_effect = [GeocoderTimedOut("Timeout"), mock_location]

        person = Person(
            first_name="Retry",
            last_name="User",
            city="New York",
            state="NY",
            country="USA"
        )
        # Use a small sleep or mock time.sleep to speed up tests if needed
        # For now, let's just run it
        with patch('time.sleep', return_value=None):
            person.save()

        self.assertEqual(mock_geocode.call_count, 2)
        self.assertEqual(person.location.x, -74.0060)

    @patch('geopy.geocoders.Nominatim.geocode')
    def test_geocoding_failure_after_retries(self, mock_geocode):
        # Mock persistent service error
        mock_geocode.side_effect = GeocoderServiceError("Service Down")

        person = Person(
            first_name="Fail",
            last_name="User",
            city="ErrorCity",
            state="ES",
            country="ErrorCountry"
        )
        
        with patch('time.sleep', return_value=None):
            with self.assertRaises(ValidationError) as cm:
                person.save()
        
        self.assertEqual(mock_geocode.call_count, 3)
        self.assertIn("Geocoding service unavailable", str(cm.exception))

    @patch('geopy.geocoders.Nominatim.geocode')
    def test_geocoding_not_found(self, mock_geocode):
        # Mock no result found
        mock_geocode.return_value = None

        person = Person(
            first_name="No",
            last_name="Result",
            city="Nowhere",
            state="ZZ",
            country="None"
        )
        
        with self.assertRaises(ValidationError) as cm:
            person.save()
            
        self.assertIn("Could not geocode address", str(cm.exception))

    def test_string_representation(self):
        person = Person(first_name="John", last_name="Doe", tag="FRIEND", location=Point(0, 0))
        self.assertEqual(str(person), "John Doe (FRIEND)")

    def test_manual_location_skips_geocoding(self):
        with patch('geopy.geocoders.Nominatim.geocode') as mock_geocode:
            person = Person(
                first_name="Manual",
                last_name="Location",
                location=Point(10, 20)
            )
            person.save()
            mock_geocode.assert_not_called()
            self.assertEqual(person.location.x, 10)
            self.assertEqual(person.location.y, 20)
