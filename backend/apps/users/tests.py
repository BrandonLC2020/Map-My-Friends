from django.test import TestCase
from django.contrib.auth.models import User
from .models import UserProfile

class UserProfileTests(TestCase):
    def test_profile_created_automatically(self):
        """Test that a UserProfile is created when a User is created."""
        user = User.objects.create_user(username='newuser', password='password123')
        self.assertTrue(hasattr(user, 'profile'))
        self.assertIsInstance(user.profile, UserProfile)
        self.assertEqual(user.profile.user, user)

    def test_profile_saved_automatically(self):
        """Test that the UserProfile is saved when the User is saved."""
        user = User.objects.create_user(username='saveuser', password='password123')
        profile = user.profile
        profile.city = 'Test City'
        user.save()
        
        # Reload from DB
        reloaded_user = User.objects.get(username='saveuser')
        self.assertEqual(reloaded_user.profile.city, 'Test City')

    def test_profile_defaults(self):
        """Test default values for UserProfile fields."""
        user = User.objects.create_user(username='defaultuser', password='password123')
        profile = user.profile
        self.assertEqual(profile.pin_color, '#2196F3')
        self.assertEqual(profile.pin_style, 'teardrop')
        self.assertEqual(profile.pin_icon_type, 'none')
        self.assertEqual(profile.distance_unit, 'metric')

    def test_string_representation(self):
        """Test the string representation of UserProfile."""
        user = User.objects.create_user(username='struser', password='password123')
        self.assertEqual(str(user.profile), "Profile for struser")

    def test_profile_cascade_delete(self):
        """Test that profile is deleted when user is deleted."""
        user = User.objects.create_user(username='deleteuser', password='password123')
        profile_id = user.profile.id
        user.delete()
        self.assertFalse(UserProfile.objects.filter(id=profile_id).exists())
