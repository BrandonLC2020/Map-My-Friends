import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../bloc/location/location_bloc.dart';
import '../shared/glass_container.dart';
import '../shared/thermal_response.dart';

class MapControls extends StatelessWidget {
  final MapController mapController;
  final bool isBottomModalVisible;

  const MapControls({
    super.key,
    required this.mapController,
    required this.isBottomModalVisible,
  });

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
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    String? tooltip,
    Color? color,
  }) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return ThermalResponse(
      onTap: onPressed,
      borderRadius: 24,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: accent),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final positionDuration = reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300);
        final bottomInset = MediaQuery.of(context).padding.bottom;
        return Stack(
          children: [
            // Pan Controls Group
            AnimatedPositioned(
              duration: positionDuration,
              curve: Curves.easeOutQuart,
              bottom: isBottomModalVisible
                  ? (isDesktop ? 180 : 268 + bottomInset)
                  : (isDesktop ? 24 : 112 + bottomInset),
              right: isDesktop ? 24 : 16,
              child: GlassContainer(
                padding: const EdgeInsets.all(8),
                borderRadius: 30, // Rounded for D-pad feel
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassButton(
                      context: context,
                      onPressed: () => _pan(0.01, 0),
                      icon: Icons.arrow_drop_up,
                      tooltip: 'Pan Up',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGlassButton(
                          context: context,
                          onPressed: () => _pan(0, -0.01),
                          icon: Icons.arrow_left,
                          tooltip: 'Pan Left',
                        ),
                        const SizedBox(width: 8),
                        _buildGlassButton(
                          context: context,
                          onPressed: () => _resetView(context),
                          icon: Icons.my_location,
                          tooltip: 'My Location',
                        ),
                        const SizedBox(width: 8),
                        _buildGlassButton(
                          context: context,
                          onPressed: () => _pan(0, 0.01),
                          icon: Icons.arrow_right,
                          tooltip: 'Pan Right',
                        ),
                      ],
                    ),
                    _buildGlassButton(
                      context: context,
                      onPressed: () => _pan(-0.01, 0),
                      icon: Icons.arrow_drop_down,
                      tooltip: 'Pan Down',
                    ),
                  ],
                ),
              ),
            ),
            // Zoom Controls Group
            AnimatedPositioned(
              duration: positionDuration,
              curve: Curves.easeOutQuart,
              bottom: isBottomModalVisible
                  ? (isDesktop ? 348 : 436 + bottomInset)
                  : (isDesktop ? 192 : 280 + bottomInset),
              right: isDesktop ? 24 : 16,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                borderRadius: 30,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildGlassButton(
                      context: context,
                      onPressed: _zoomIn,
                      icon: Icons.add,
                      tooltip: 'Zoom In',
                    ),
                    const SizedBox(height: 8),
                    _buildGlassButton(
                      context: context,
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
      },
    );
  }
}
