from django.contrib.gis.db import models


class Station(models.Model):
    STATION_TYPE_CHOICES = [
        ('major_station', 'Major Station'),
        ('commuter_rail_station', 'Commuter Rail Station'),
        ('subway_station', 'Subway Station'),
        ('regional_station', 'Regional Station'),
    ]

    name = models.CharField(max_length=255)
    osm_id = models.BigIntegerField(unique=True)
    station_type = models.CharField(
        max_length=25,
        choices=STATION_TYPE_CHOICES,
        default='major_station'
    )
    uic_ref = models.CharField(max_length=100, blank=True)
    city = models.CharField(max_length=255, blank=True)
    country = models.CharField(max_length=100, blank=True)
    location = models.PointField(srid=4326)

    class Meta:
        ordering = ['name']

    @classmethod
    def get_nearby(cls, point, radius_km=None, count=10):
        """Returns stations ordered by distance from a given point."""
        from django.contrib.gis.db.models.functions import Distance
        from django.contrib.gis.measure import D
        
        queryset = cls.objects.annotate(distance=Distance('location', point))
        if radius_km:
            queryset = queryset.filter(location__distance_lte=(point, D(km=radius_km)))
        
        return queryset.order_by('distance')[:count]

    def __str__(self):
        return f"{self.name} ({self.osm_id})"
