import 'package:flutter_bloc/flutter_bloc.dart';
import 'profile_event.dart';
import 'profile_state.dart';
import '../../services/auth_service.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthService _authService;

  ProfileBloc({AuthService? authService})
    : _authService = authService ?? AuthService(),
      super(ProfileInitial()) {
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<UploadProfileImage>(_onUploadProfileImage);
  }

  Future<void> _onLoadProfile(
    LoadProfile event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    try {
      final profile = await _authService.getProfile();
      emit(
        ProfileLoaded(
          username: profile['username'],
          email: profile['email'],
          firstName: profile['first_name'],
          lastName: profile['last_name'],
          profileImageUrl: _processImageUrl(profile['profile_image']),
          city: profile['city'],
          state: profile['state'],
          country: profile['country'],
          street: profile['street'],
        ),
      );
    } catch (e) {
      emit(ProfileError(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    emit(ProfileUpdating());

    try {
      final profile = await _authService.updateProfile(
        city: event.city,
        state: event.state,
        country: event.country,
        street: event.street,
      );
      emit(
        ProfileLoaded(
          username: profile['username'],
          email: profile['email'],
          firstName: profile['first_name'],
          lastName: profile['last_name'],
          profileImageUrl: _processImageUrl(profile['profile_image']),
          city: profile['city'],
          state: profile['state'],
          country: profile['country'],
          street: profile['street'],
        ),
      );
    } catch (e) {
      if (currentState is ProfileLoaded) {
        emit(currentState);
      }
      emit(ProfileError(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onUploadProfileImage(
    UploadProfileImage event,
    Emitter<ProfileState> emit,
  ) async {
    final currentState = state;
    emit(ProfileUpdating());

    try {
      final profile = await _authService.uploadProfileImage(event.image);
      emit(
        ProfileLoaded(
          username: profile['username'],
          email: profile['email'],
          firstName: profile['first_name'],
          lastName: profile['last_name'],
          profileImageUrl: _processImageUrl(profile['profile_image']),
          city: profile['city'],
          state: profile['state'],
          country: profile['country'],
          street: profile['street'],
        ),
      );
    } catch (e) {
      if (currentState is ProfileLoaded) {
        emit(currentState);
      }
      emit(ProfileError(message: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  String? _processImageUrl(String? url) {
    if (url == null) return null;
    // Add timestamp to force cache refresh
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (url.contains('?')) {
      return '$url&t=$timestamp';
    }
    return '$url?t=$timestamp';
  }
}
