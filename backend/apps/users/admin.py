from django.contrib import admin
from .models import UserProfile


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'city', 'state', 'country')
    search_fields = ('user__username', 'city', 'state', 'country')
