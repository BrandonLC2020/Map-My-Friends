import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/location/location_bloc.dart';
import '../bloc/people/people_bloc.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: BlocBuilder<LocationBloc, LocationState>(
        builder: (context, locationState) {
          if (locationState is LocationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          LatLng center = const LatLng(37.7749, -122.4194); // Default SF
          if (locationState is LocationLoaded &&
              locationState.position != null) {
            center = LatLng(
              locationState.position!.latitude,
              locationState.position!.longitude,
            );
          }

          return BlocBuilder<PeopleBloc, PeopleState>(
            builder: (context, peopleState) {
              List<Marker> markers = [];
              if (locationState is LocationLoaded &&
                  locationState.position != null) {
                markers.add(
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                );
              }

              if (peopleState is PeopleLoaded) {
                markers.addAll(
                  peopleState.people
                      .where((p) => p.latitude != null && p.longitude != null)
                      .map(
                        (p) => Marker(
                          point: LatLng(p.latitude!, p.longitude!),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('${p.firstName} ${p.lastName}'),
                                  content: Text('${p.city}, ${p.state}'),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                );
              }

              return FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 13.0),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
