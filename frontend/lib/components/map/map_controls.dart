import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../bloc/location/location_bloc.dart';
import '../../utils/window_size.dart';
import '../shared/glass_container.dart';
import '../shared/thermal_response.dart';
import '../../utils/app_theme.dart';

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
        final window = MapWindow(
          Size(constraints.maxWidth, constraints.maxHeight),
        );
        final reduceMotion = MediaQuery.disableAnimationsOf(context);
        final positionDuration = reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300);
        // Only the bar sits in the safe area; a rail leaves the bottom free.
        final bottomInset = window.usesBar
            ? MediaQuery.of(context).padding.bottom
            : 0.0;
        final panGroup = GlassContainer(
          padding: const EdgeInsets.all(8),
          borderRadius: MapGlass.radiusLg, // Rounded for D-pad feel
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
        );

        final zoomGroup = GlassContainer(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          borderRadius: MapGlass.radiusLg,
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
        );

        final bottom =
            (isBottomModalVisible ? 180 : 24) +
            window.navBarInset +
            bottomInset;

        // A short window lays the two groups out side by side along its
        // abundant axis, the same trade the navigation makes. Stacked, they
        // walled off most of the right edge of a landscape phone.
        if (window.isShortHeight) {
          return Stack(
            children: [
              AnimatedPositioned(
                duration: positionDuration,
                curve: Curves.easeOutQuart,
                bottom: bottom,
                right: window.edgeInset,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [zoomGroup, const SizedBox(width: 12), panGroup],
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            AnimatedPositioned(
              duration: positionDuration,
              curve: Curves.easeOutQuart,
              bottom: bottom,
              right: window.edgeInset,
              child: panGroup,
            ),
            AnimatedPositioned(
              duration: positionDuration,
              curve: Curves.easeOutQuart,
              bottom:
                  (isBottomModalVisible ? 348 : 192) +
                  window.navBarInset +
                  bottomInset,
              right: window.edgeInset,
              child: zoomGroup,
            ),
          ],
        );
      },
    );
  }
}
