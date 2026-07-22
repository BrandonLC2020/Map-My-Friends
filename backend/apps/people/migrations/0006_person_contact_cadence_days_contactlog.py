import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('people', '0005_person_preferred_airport_person_preferred_station'),
    ]

    operations = [
        migrations.AddField(
            model_name='person',
            name='contact_cadence_days',
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.CreateModel(
            name='ContactLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('channel', models.CharField(choices=[('CALL', 'Call'), ('VIDEO', 'Video chat'), ('MESSAGE', 'Message')], max_length=10)),
                ('contacted_at', models.DateTimeField()),
                ('note', models.CharField(blank=True, max_length=280, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('person', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='contact_logs', to='people.person')),
            ],
            options={
                'ordering': ['-contacted_at'],
            },
        ),
        migrations.AddIndex(
            model_name='contactlog',
            index=models.Index(fields=['person', '-contacted_at'], name='people_contactlog_recent_idx'),
        ),
    ]
