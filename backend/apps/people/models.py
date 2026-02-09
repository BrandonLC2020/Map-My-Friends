from django.contrib.gis.db import models


class Person(models.Model):
    TAG_CHOICES = [
        ('FRIEND', 'Friend'),
        ('FAMILY', 'Family'),
    ]

    tag = models.CharField(max_length=10, choices=TAG_CHOICES)
    
    first_name = models.CharField(max_length=100, default="")
    last_name = models.CharField(max_length=100, default="")
    
    city = models.CharField(max_length=100, default="")
    state = models.CharField(max_length=100, default="")
    country = models.CharField(max_length=100, default="")
    street = models.CharField(max_length=255, blank=True, null=True)
    
    birthday = models.DateField(blank=True, null=True)
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    
    profile_image = models.ImageField(upload_to='profile_images/', blank=True, null=True)
    
    location = models.PointField()

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.tag})"
