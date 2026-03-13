import json
from django.contrib.gis.geos import Point
from django.core.management.base import BaseCommand
from apps.stations.models import Station


class Command(BaseCommand):
    help = "Import train stations from OSM/Overpass JSON data."

    def add_arguments(self, parser):
        parser.add_argument(
            'file_path',
            type=str,
            help='Path to the JSON file containing station data.',
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Delete all existing stations before importing.',
        )

    def handle(self, *args, **options):
        file_path = options['file_path']
        if options['clear']:
            deleted_count, _ = Station.objects.all().delete()
            self.stdout.write(f"Deleted {deleted_count} existing stations.")

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            self.stderr.write(f"Error reading file: {e}")
            return

        MAJOR_NAMES = {
            "New York Penn Station", "Washington Union Station", "Boston South Station",
            "Philadelphia 30th Street Station", "Baltimore Penn Station", "Chicago Union Station",
            "St. Louis Gateway Center", "Kansas City Union Station", "Denver Union Station",
            "Salt Lake City Central Station", "Seattle King Street Station", "Portland Union Station",
            "Los Angeles Union Station", "Atlanta Peachtree Station", "New Orleans Union Passenger Terminal",
            "Miami Central Station", "Dallas Union Station", "Houston Amtrak Station",
            "Charlotte Amtrak Station", "St. Paul Union Depot", "Milwaukee Intermodal Station",
            "Detroit Amtrak Station", "Cleveland Amtrak Station", "Indianapolis Union Station",
            "Albuquerque Alvarado Center", "Flagstaff Amtrak Station", "San Diego Santa Fe Depot",
            "San Jose Diridon Station", "Sacramento Valley Station", "Stamford Station",
            "New Haven Union Station", "Providence Station", "Newark Penn Station",
            "Orlando Amtrak Station", "Richmond Staples Mill Road", "Raleigh Union Station",
            "Pittsburgh Union Station", "Cincinnati Union Terminal", "Vancouver Amtrak Station",
            "Oakland Jack London Square", "Union Station", "South Station", "Penn Station"
        }

        elements = data.get('elements', [])
        stations_to_create = []
        stations_to_update = []
        
        # Optimization: Fetch existing OSM IDs
        existing_osm_ids = set(
            Station.objects.values_list('osm_id', flat=True)
        )

        for el in elements:
            if el.get('type') != 'node':
                continue
            
            tags = el.get('tags', {})
            name = tags.get('name')
            if not name:
                continue

            osm_id = el.get('id')
            lat = el.get('lat')
            lon = el.get('lon')

            if osm_id is None or lat is None or lon is None:
                continue

            # Categorization logic
            operator = tags.get('operator', '')
            network = tags.get('network', '')
            st_type = 'regional_station'
            
            # 1. Identify Amtrak / Intercity (Major)
            is_amtrak = (
                'Amtrak' in name or 
                'Amtrak' in operator or 
                'Amtrak' in network or
                'amtrak:code' in tags
            )
            
            if name in MAJOR_NAMES or is_amtrak or 'uic_ref' in tags:
                st_type = 'major_station'
            # 2. Identify Subway / Metro
            elif (
                'Subway' in name or 
                'Metro' in name or 
                'BART' in name or
                'Path Station' in name or
                tags.get('railway') == 'subway' or
                tags.get('station') == 'subway'
            ):
                st_type = 'subway_station'
            # 3. Identify Commuter Rail
            elif (
                'LIRR' in network or 
                'Metro-North' in network or 
                'NJ Transit' in network or
                'MBTA' in network or
                'Caltrain' in network or
                'Metra' in network or
                'SEPTA' in network or
                'Metrolink' in network or
                'commuter' in tags.get('railway', '') or
                'commuter' in network.lower()
            ):
                st_type = 'commuter_rail_station'

            station_data = {
                'name': name,
                'osm_id': osm_id,
                'station_type': st_type,
                'uic_ref': tags.get('uic_ref', tags.get('amtrak:code', '')),
                'city': tags.get('addr:city', ''),
                'country': tags.get('addr:country', 'USA'),
                'location': Point(lon, lat, srid=4326),
            }

            if osm_id in existing_osm_ids:
                stations_to_update.append(station_data)
            else:
                stations_to_create.append(Station(**station_data))

        # Bulk create new stations
        if stations_to_create:
            Station.objects.bulk_create(stations_to_create, ignore_conflicts=True)
            self.stdout.write(f"Created {len(stations_to_create)} new stations.")

        # Update existing stations
        updated_count = 0
        for data in stations_to_update:
            oid = data.pop('osm_id')
            Station.objects.filter(osm_id=oid).update(**data)
            updated_count += 1

        if updated_count:
            self.stdout.write(f"Updated {updated_count} existing stations.")

        total = Station.objects.count()
        self.stdout.write(
            self.style.SUCCESS(f"Done! Total stations in database: {total}")
        )
