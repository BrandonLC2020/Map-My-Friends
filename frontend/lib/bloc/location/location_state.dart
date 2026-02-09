part of 'location_bloc.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationLoaded extends LocationState {
  final Position? position;
  final String? address; // For display purposes if needed

  const LocationLoaded({this.position, this.address});

  @override
  List<Object> get props => [position ?? '', address ?? ''];
}

class LocationError extends LocationState {
  final String message;

  const LocationError(this.message);

  @override
  List<Object> get props => [message];
}

class LocationPermissionDenied extends LocationState {}

class LocationPermissionDeniedForever extends LocationState {}
