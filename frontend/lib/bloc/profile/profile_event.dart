import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load the user's profile from the server
class LoadProfile extends ProfileEvent {}

/// Update profile fields (address)
class UpdateProfile extends ProfileEvent {
  final String? firstName;
  final String? lastName;
  final String? city;
  final String? state;
  final String? country;
  final String? street;
  final String? birthDate;
  final String? phoneNumber;
  final String? pinColor;
  final String? pinStyle;
  final String? pinIconType;
  final String? pinEmoji;

  const UpdateProfile({
    this.firstName,
    this.lastName,
    this.city,
    this.state,
    this.country,
    this.street,
    this.birthDate,
    this.phoneNumber,
    this.pinColor,
    this.pinStyle,
    this.pinIconType,
    this.pinEmoji,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    city,
    state,
    country,
    street,
    birthDate,
    phoneNumber,
    pinColor,
    pinStyle,
    pinIconType,
    pinEmoji,
  ];
}

/// Upload a new profile image
class UploadProfileImage extends ProfileEvent {
  final XFile image;

  const UploadProfileImage({required this.image});

  @override
  List<Object?> get props => [image];
}
