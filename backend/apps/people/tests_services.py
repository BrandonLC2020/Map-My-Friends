from unittest.mock import MagicMock, patch

from django.core.exceptions import ValidationError
from django.test import SimpleTestCase

from apps.people.services import geocode_address


class GeocodeAddressTests(SimpleTestCase):
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_returns_coordinates_and_timezone(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = MagicMock(
            latitude=41.8781, longitude=-87.6298
        )
        mock_tf.return_value.timezone_at.return_value = "America/Chicago"

        lat, lng, tz = geocode_address("Chicago", "IL", "USA")

        self.assertAlmostEqual(lat, 41.8781)
        self.assertAlmostEqual(lng, -87.6298)
        self.assertEqual(tz, "America/Chicago")

    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_raises_validation_error_when_not_found(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = None

        with self.assertRaises(ValidationError):
            geocode_address("Nowhereville", "ZZ", "XX")

    @patch("apps.people.services.time.sleep")
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_retries_on_timeout_then_succeeds(self, mock_nominatim, mock_tf, mock_sleep):
        from geopy.exc import GeocoderTimedOut

        mock_nominatim.return_value.geocode.side_effect = [
            GeocoderTimedOut(),
            MagicMock(latitude=1.0, longitude=2.0),
        ]
        mock_tf.return_value.timezone_at.return_value = "UTC"

        lat, lng, tz = geocode_address("Somewhere", "ST", "CC")

        self.assertEqual((lat, lng, tz), (1.0, 2.0, "UTC"))
        self.assertEqual(mock_nominatim.return_value.geocode.call_count, 2)

    @patch("apps.people.services.time.sleep")
    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_raises_after_exhausting_retries(self, mock_nominatim, mock_tf, mock_sleep):
        from geopy.exc import GeocoderServiceError

        mock_nominatim.return_value.geocode.side_effect = GeocoderServiceError()

        with self.assertRaises(ValidationError):
            geocode_address("Somewhere", "ST", "CC")

    @patch("apps.people.services.TimezoneFinder")
    @patch("apps.people.services.Nominatim")
    def test_street_included_in_query_when_provided(self, mock_nominatim, mock_tf):
        mock_nominatim.return_value.geocode.return_value = MagicMock(
            latitude=1.0, longitude=2.0
        )
        mock_tf.return_value.timezone_at.return_value = "UTC"

        geocode_address("Chicago", "IL", "USA", street="123 Main St")

        query = mock_nominatim.return_value.geocode.call_args[0][0]
        self.assertEqual(query["street"], "123 Main St")
