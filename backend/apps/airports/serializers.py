from rest_framework import serializers

from apps.common.serializers import GeoFeatureSerializer


class AirportSerializer(GeoFeatureSerializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True)
    iata_code = serializers.CharField(read_only=True)
    icao_code = serializers.CharField(read_only=True, allow_blank=True)
    airport_type = serializers.CharField(read_only=True)
    city = serializers.CharField(read_only=True, allow_blank=True)
    country = serializers.CharField(read_only=True, allow_blank=True)
    continent = serializers.CharField(read_only=True, allow_blank=True)
    lat = serializers.FloatField(read_only=True)
    lng = serializers.FloatField(read_only=True)
    distance_km = serializers.FloatField(read_only=True, required=False)
