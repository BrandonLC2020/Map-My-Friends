import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MapType { standard, satellite, minimal }

class MapSettingsState extends Equatable {
  final bool showControls;
  final MapType mapType;

  const MapSettingsState({
    this.showControls = true,
    this.mapType = MapType.standard,
  });

  MapSettingsState copyWith({bool? showControls, MapType? mapType}) {
    return MapSettingsState(
      showControls: showControls ?? this.showControls,
      mapType: mapType ?? this.mapType,
    );
  }

  @override
  List<Object> get props => [showControls, mapType];
}

class MapSettingsCubit extends Cubit<MapSettingsState> {
  MapSettingsCubit() : super(const MapSettingsState());

  void toggleControls() {
    emit(state.copyWith(showControls: !state.showControls));
  }

  void setMapType(MapType type) {
    emit(state.copyWith(mapType: type));
  }
}
