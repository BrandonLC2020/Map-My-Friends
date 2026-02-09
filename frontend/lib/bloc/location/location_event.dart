part of 'location_bloc.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object> get props => [];
}

class LoadLocation extends LocationEvent {}

class RequestPermission extends LocationEvent {}

class UpdateUserAddress extends LocationEvent {
  final String city;
  final String state;
  final String country;
  final String? street;

  const UpdateUserAddress({
    required this.city,
    required this.state,
    required this.country,
    this.street,
  });

  @override
  List<Object> get props => [city, state, country, street ?? ''];
}
