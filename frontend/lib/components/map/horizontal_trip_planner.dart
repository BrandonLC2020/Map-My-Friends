import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../bloc/trip/trip_bloc.dart';
import '../../bloc/trip/trip_event.dart';
import '../../bloc/trip/trip_state.dart';
import '../../models/trip.dart';
import '../../utils/app_theme.dart';
import '../shared/glass_container.dart';

class HorizontalTripPlanner extends StatelessWidget {
  const HorizontalTripPlanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripBloc, TripState>(
      builder: (context, state) {
        if (state.stops.isEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: GlassContainer(
            height: 140,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.stops.length,
                    itemBuilder: (context, index) {
                      final stop = state.stops[index];
                      String name = 'Stop';
                      IconData? icon;
                      // Default is "person-only" — the rare Aurora Pink slot,
                      // reserved by DESIGN.md for trip-this-week markers.
                      Color color = scheme.secondary;
                      Color onColor = scheme.onSecondary;

                      if (stop.airport != null) {
                        name = stop.airport!.iataCode;
                        icon = Icons.flight;
                        color = MapPalette.airport;
                        onColor = Colors.white;
                      } else if (stop.station != null) {
                        name = stop.station!.name;
                        icon = Icons.train;
                        color = MapPalette.majorStation;
                        onColor = Colors.white;
                      } else if (stop.people.isNotEmpty) {
                        name = stop.people.first.firstName;
                        if (stop.people.length > 1) {
                          name += ' +${stop.people.length - 1}';
                        }
                      }

                      final letter = String.fromCharCode(65 + index);

                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  backgroundColor: color,
                                  foregroundColor: onColor,
                                  child: icon != null
                                      ? Icon(icon, size: 20)
                                      : Text(
                                          letter,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                if (stop.people.isNotEmpty &&
                                    (stop.airport != null ||
                                        stop.station != null))
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: scheme.secondary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        stop.people.length.toString(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSecondary,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (stop.people.isNotEmpty &&
                                (stop.airport != null || stop.station != null))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: -8,
                                  children: stop.people.take(3).map((p) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.dividerColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundImage:
                                            p.profileImageUrl != null
                                            ? NetworkImage(p.profileImageUrl!)
                                            : null,
                                        child: p.profileImageUrl == null
                                            ? Text(
                                                p.firstName[0],
                                                style: const TextStyle(
                                                  fontSize: 8,
                                                ),
                                              )
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: theme.dividerColor,
                ),
                SizedBox(
                  height: 140,
                  child: _ActionGroup(
                    onSave: () {
                      final now = DateTime.now();
                      final dateStr = DateFormat('yyyy-MM-dd').format(now);
                      context.read<TripBloc>().add(
                        SaveTrip(
                          name: "Draft Trip $dateStr",
                          startDate: now,
                          endDate: now,
                          status: TripStatus.draft,
                        ),
                      );
                    },
                    onClear: () {
                      context.read<TripBloc>().add(const ClearTrip());
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionGroup extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onClear;

  const _ActionGroup({required this.onSave, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.check_circle, color: scheme.primary),
          onPressed: onSave,
          tooltip: 'Save Trip',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        IconButton(
          icon: Icon(Icons.layers_clear, color: scheme.error),
          onPressed: onClear,
          tooltip: 'Clear Trip',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
      ],
    );
  }
}
