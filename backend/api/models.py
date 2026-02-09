from django.contrib.gis.db import models

class Person(models.Model):
    TAG_CHOICES = [
        ('FRIEND', 'Friend'),
        ('FAMILY', 'Family'),
    ]

    tag = models.CharField(max_length=10, choices=TAG_CHOICES)
    location = models.PointField()

    def __str__(self):
        return f"{self.tag} at {self.location}"
