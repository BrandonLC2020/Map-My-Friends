from django.contrib import admin
from .models import Person, ContactLog


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ('id', 'first_name', 'last_name', 'tag', 'city', 'state', 'country')
    list_filter = ('tag',)
    search_fields = ('first_name', 'last_name', 'city', 'state', 'country')


@admin.register(ContactLog)
class ContactLogAdmin(admin.ModelAdmin):
    list_display = ('id', 'person', 'channel', 'contacted_at', 'created_at')
    list_filter = ('channel', 'contacted_at')
    search_fields = ('person__first_name', 'person__last_name', 'note')
    autocomplete_fields = ('person',)
    date_hierarchy = 'contacted_at'
