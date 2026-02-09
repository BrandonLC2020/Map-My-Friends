from rest_framework import serializers
from django.contrib.gis.geos import Point
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Person


class PersonSerializer(GeoFeatureModelSerializer):
    latitude = serializers.FloatField(write_only=True, required=False)
    longitude = serializers.FloatField(write_only=True, required=False)

    class Meta:
        model = Person
        geo_field = "location"
        fields = (
            'id',
            'first_name',
            'last_name',
            'tag',
            'city',
            'state',
            'country',
            'street',
            'birthday',
            'phone_number',
            'profile_image',
            'location',
            'latitude',
            'longitude',
        )
        read_only_fields = ('location',)

    def validate(self, attrs):
        latitude = attrs.pop('latitude', None)
        longitude = attrs.pop('longitude', None)

        if latitude is not None and longitude is not None:
            attrs['location'] = Point(longitude, latitude)
            
        return attrs
