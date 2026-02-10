from django.contrib.gis.db import models


class Person(models.Model):
    TAG_CHOICES = [
        ('FRIEND', 'Friend'),
        ('FAMILY', 'Family'),
    ]

    tag = models.CharField(max_length=10, choices=TAG_CHOICES)
    
    first_name = models.CharField(max_length=100, default="")
    last_name = models.CharField(max_length=100, default="")
    
    city = models.CharField(max_length=100, default="")
    state = models.CharField(max_length=100, default="")
    country = models.CharField(max_length=100, default="")
    street = models.CharField(max_length=255, blank=True, null=True)
    
    birthday = models.DateField(blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    
    profile_image = models.ImageField(upload_to='profile_images/', blank=True, null=True)
    
    location = models.PointField()

    def save(self, *args, **kwargs):
        if not self.location:
            from geopy.geocoders import Nominatim
            from geopy.exc import GeocoderTimedOut, GeocoderServiceError
            from django.contrib.gis.geos import Point
            from django.core.exceptions import ValidationError
            import time

            geolocator = Nominatim(user_agent="map_my_friends_global_connect")
            address = f"{self.street or ''}, {self.city}, {self.state}, {self.country}".strip(", ")
            
            for attempt in range(3):
                try:
                    location = geolocator.geocode(address)
                    if location:
                        self.location = Point(location.longitude, location.latitude)
                        break
                except (GeocoderTimedOut, GeocoderServiceError):
                    if attempt < 2:
                        time.sleep(1)
                    else:
                        raise ValidationError("Geocoding service unavailable. Please try again later.")
            else:
                if not self.location:
                    raise ValidationError(f"Could not geocode address: {address}")

        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.tag})"
