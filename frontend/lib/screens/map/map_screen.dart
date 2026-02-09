import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../bloc/location/location_bloc.dart';
import '../../bloc/people/people_bloc.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  void _pan(double latDelta, double lonDelta) {
    final currentCenter = _mapController.camera.center;
    final newCenter = LatLng(
      currentCenter.latitude + latDelta,
      currentCenter.longitude + lonDelta,
    );
    _mapController.move(newCenter, _mapController.camera.zoom);
  }

  void _resetView() {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded && locationState.position != null) {
      _mapController.move(
        LatLng(
          locationState.position!.latitude,
          locationState.position!.longitude,
        ),
        13.0,
      );
    } else {
      _mapController.move(const LatLng(37.7749, -122.4194), 13.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: BlocConsumer<LocationBloc, LocationState>(
        listener: (context, state) {
          if (state is LocationLoaded && state.position != null) {
            _mapController.move(
              LatLng(state.position!.latitude, state.position!.longitude),
              13.0,
            );
          }
        },
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

              return Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: 'zoom_in',
                          onPressed: _zoomIn,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 10),
                        FloatingActionButton(
                          heroTag: 'zoom_out',
                          onPressed: _zoomOut,
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton(
                          heroTag: 'pan_up',
                          onPressed: () => _pan(0.01, 0),
                          child: const Icon(Icons.arrow_drop_up),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton(
                              heroTag: 'pan_left',
                              onPressed: () => _pan(0, -0.01),
                              child: const Icon(Icons.arrow_left),
                            ),
                            const SizedBox(width: 10),
                            FloatingActionButton(
                              heroTag: 'reset_view',
                              onPressed: _resetView,
                              child: const Icon(Icons.my_location),
                            ),
                            const SizedBox(width: 10),
                            FloatingActionButton(
                              heroTag: 'pan_right',
                              onPressed: () => _pan(0, 0.01),
                              child: const Icon(Icons.arrow_right),
                            ),
                          ],
                        ),
                        FloatingActionButton(
                          heroTag: 'pan_down',
                          onPressed: () => _pan(-0.01, 0),
                          child: const Icon(Icons.arrow_drop_down),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
