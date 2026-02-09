import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'models/person.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map My Friends',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Person> _people = [];
  LatLng? _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchPeople();
    _determinePosition();
  }

  Future<void> _fetchPeople() async {
    try {
      // Use localhost:8000 for iOS simulator / Web / macOS
      // Use 10.0.2.2:8000 for Android emulator
      final response = await http.get(
        Uri.parse('http://localhost:8000/people/'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> features = data['features'];
        setState(() {
          _people = features.map((json) => Person.fromJson(json)).toList();
        });
      } else {
        print('Failed to load people: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching people: $e');
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });

    // Optionally move map to user location
    // _mapController.move(_currentLocation!, 13.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map My Friends')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter:
              _currentLocation ??
              const LatLng(
                51.509364,
                -0.128928,
              ), // Default to London or user location
          initialZoom: 9.2,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              if (_currentLocation != null)
                Marker(
                  point: _currentLocation!,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
              ..._people.map(
                (person) => Marker(
                  point: person.location,
                  width: 80,
                  height: 80,
                  child: Icon(
                    Icons.location_on,
                    color: person.tag == RelationshipType.FRIEND
                        ? Colors.blue
                        : Colors.red,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fetchPeople();
          _determinePosition();
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
