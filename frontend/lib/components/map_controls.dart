import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../bloc/location/location_bloc.dart';
import 'glass_container.dart';

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

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required IconData icon,
    String? tooltip,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: Colors.indigo,
      ), // Changed to Indigo for readability
      tooltip: tooltip,
      style: IconButton.styleFrom(hoverColor: Colors.indigo.withOpacity(0.1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Pan Controls Group
        Positioned(
          bottom: 20,
          right: 20,
          child: GlassContainer(
            padding: const EdgeInsets.all(4),
            borderRadius: 30, // Rounded for D-pad feel
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGlassButton(
                  onPressed: () => _pan(0.01, 0),
                  icon: Icons.arrow_drop_up,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassButton(
                      onPressed: () => _pan(0, -0.01),
                      icon: Icons.arrow_left,
                    ),
                    const SizedBox(width: 4),
                    _buildGlassButton(
                      onPressed: () => _resetView(context),
                      icon: Icons.my_location,
                      tooltip: 'My Location',
                    ),
                    const SizedBox(width: 4),
                    _buildGlassButton(
                      onPressed: () => _pan(0, 0.01),
                      icon: Icons.arrow_right,
                    ),
                  ],
                ),
                _buildGlassButton(
                  onPressed: () => _pan(-0.01, 0),
                  icon: Icons.arrow_drop_down,
                ),
              ],
            ),
          ),
        ),
        // Zoom Controls Group
        Positioned(
          bottom: 180, // Positioned above the pan controls
          right: 20,
          child: GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGlassButton(
                  onPressed: _zoomIn,
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 4),
                const Icon(Icons.search, color: Colors.indigo, size: 20),
                const SizedBox(height: 4),
                _buildGlassButton(
                  onPressed: _zoomOut,
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
