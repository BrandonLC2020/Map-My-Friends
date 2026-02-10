import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/map/map_settings_cubit.dart';
import '../shared/glass_container.dart';

class MapSettingsModal extends StatelessWidget {
  const MapSettingsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Map Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white, // Ensure visibility on glass
              ),
            ),
            const SizedBox(height: 20),
            BlocBuilder<MapSettingsCubit, MapSettingsState>(
              builder: (context, state) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Show Map Controls'),
                      value: state.showControls,
                      onChanged: (value) {
                        context.read<MapSettingsCubit>().toggleControls();
                      },
                      secondary: const Icon(Icons.control_camera),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Map Type'),
                      trailing: DropdownButton<MapType>(
                        value: state.mapType,
                        onChanged: (MapType? newValue) {
                          if (newValue != null) {
                            context.read<MapSettingsCubit>().setMapType(
                              newValue,
                            );
                          }
                        },
                        items: MapType.values.map((MapType type) {
                          return DropdownMenuItem<MapType>(
                            value: type,
                            child: Text(type.name.toUpperCase()),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
