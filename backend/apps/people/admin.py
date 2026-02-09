from django.contrib import admin
from .models import Person


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ('id', 'first_name', 'last_name', 'tag', 'city', 'state', 'country')
    list_filter = ('tag',)
    search_fields = ('first_name', 'last_name', 'city', 'state', 'country')
