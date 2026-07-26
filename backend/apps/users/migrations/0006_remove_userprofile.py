from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('users', '0005_userprofile_distance_unit'),
    ]

    operations = [
        migrations.DeleteModel(name='UserProfile'),
    ]
