from rest_framework import serializers
from django.contrib.gis.geos import Point
from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Person


class PersonSerializer(GeoFeatureModelSerializer):
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
            'timezone',
            'pin_color',
            'pin_style',
            'pin_icon_type',
            'pin_emoji',
        )
        read_only_fields = ('location', 'timezone')
