import 'package:equatable/equatable.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load the user's profile from the server
class LoadProfile extends ProfileEvent {}

/// Update profile fields (address)
class UpdateProfile extends ProfileEvent {
  final String? city;
  final String? state;
  final String? country;
  final String? street;

  const UpdateProfile({this.city, this.state, this.country, this.street});

  @override
  List<Object?> get props => [city, state, country, street];
}

/// Upload a new profile image
class UploadProfileImage extends ProfileEvent {
  final String imagePath;

  const UploadProfileImage({required this.imagePath});

  @override
  List<Object?> get props => [imagePath];
}
