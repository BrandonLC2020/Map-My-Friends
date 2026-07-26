from rest_framework import serializers

from apps.common.serializers import GeoFeatureSerializer


class StationSerializer(GeoFeatureSerializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True)
    osm_id = serializers.IntegerField(read_only=True)
    station_type = serializers.CharField(read_only=True)
    uic_ref = serializers.CharField(read_only=True, allow_blank=True)
    city = serializers.CharField(read_only=True, allow_blank=True)
    country = serializers.CharField(read_only=True, allow_blank=True)
    lat = serializers.FloatField(read_only=True)
    lng = serializers.FloatField(read_only=True)
    distance_km = serializers.FloatField(read_only=True, required=False)
