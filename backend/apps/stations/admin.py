from django.contrib.gis import admin
from .models import Station

@admin.register(Station)
class StationAdmin(admin.GISModelAdmin):
    list_display = ('name', 'station_type', 'city', 'country', 'osm_id')
    list_filter = ('station_type', 'country')
    search_fields = ('name', 'city', 'osm_id')
