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
        )
        read_only_fields = ('location',)
