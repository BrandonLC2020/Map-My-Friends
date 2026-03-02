import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/map/map_settings_cubit.dart';
import '../shared/glass_container.dart';
import 'map_settings_modal.dart';

class MapSettingsButton extends StatelessWidget {
  const MapSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      top:
          60, // Default top position, will be overridden by LayoutBuilder logic inside if needed
      child: LayoutBuilder(
        builder: (context, constraints) {
          // You can't dynamically change Positioned's properties here without moving
          // Positioned OUTSIDE of LayoutBuilder.
          // Getting screen width directly from MediaQuery is safer inside a Stack.
          final isDesktop = MediaQuery.of(context).size.width >= 600;
          return Transform.translate(
            offset: Offset(
              0,
              isDesktop ? 0 : 60,
            ), // Account for the extra 60 padding on mobile
            child: GlassContainer(
              padding: const EdgeInsets.all(8),
              borderRadius: 30,
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.indigo),
                tooltip: 'Map Settings',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) {
                      // Pass the existing cubit to the modal
                      return BlocProvider.value(
                        value: context.read<MapSettingsCubit>(),
                        child: const MapSettingsModal(),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
