from rest_framework_gis.serializers import GeoFeatureModelSerializer
from .models import Person

class PersonSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Person
        geo_field = "location"
        fields = ('id', 'tag', 'location')
