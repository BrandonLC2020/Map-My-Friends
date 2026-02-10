import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MapType { standard, satellite, minimal }

class MapSettingsState extends Equatable {
  final bool showControls;
  final MapType mapType;
  final ThemeMode themeMode;

  const MapSettingsState({
    this.showControls = true,
    this.mapType = MapType.standard,
    this.themeMode = ThemeMode.system,
  });

  MapSettingsState copyWith({
    bool? showControls,
    MapType? mapType,
    ThemeMode? themeMode,
  }) {
    return MapSettingsState(
      showControls: showControls ?? this.showControls,
      mapType: mapType ?? this.mapType,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object> get props => [showControls, mapType, themeMode];
}

class MapSettingsCubit extends Cubit<MapSettingsState> {
  MapSettingsCubit() : super(const MapSettingsState());

  void toggleControls() {
    emit(state.copyWith(showControls: !state.showControls));
  }

  void setMapType(MapType type) {
    emit(state.copyWith(mapType: type));
  }

  void setMapTheme(ThemeMode mode) {
    emit(state.copyWith(themeMode: mode));
  }
}
