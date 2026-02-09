import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/location/location_bloc.dart';

class MapControls extends StatelessWidget {
  final MapController mapController;

  const MapControls({super.key, required this.mapController});

  void _zoomIn() {
    mapController.move(
      mapController.camera.center,
      mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    mapController.move(
      mapController.camera.center,
      mapController.camera.zoom - 1,
    );
  }

  void _pan(double latDelta, double lonDelta) {
    final currentCenter = mapController.camera.center;
    final newCenter = LatLng(
      currentCenter.latitude + latDelta,
      currentCenter.longitude + lonDelta,
    );
    mapController.move(newCenter, mapController.camera.zoom);
  }

  void _resetView(BuildContext context) {
    final locationState = context.read<LocationBloc>().state;
    if (locationState is LocationLoaded && locationState.position != null) {
      mapController.move(
        LatLng(
          locationState.position!.latitude,
          locationState.position!.longitude,
        ),
        13.0,
      );
    } else {
      mapController.move(const LatLng(37.7749, -122.4194), 13.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
                    onPressed: () => _resetView(context),
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
  }
}
