import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final String accessToken;
  final String refreshToken;
  final String? username;

  const Authenticated({
    required this.accessToken,
    required this.refreshToken,
    this.username,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken, username];
}

class Unauthenticated extends AuthState {
  final String? message;

  const Unauthenticated({this.message});

  @override
  List<Object?> get props => [message];
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

class PasswordResetSent extends AuthState {
  final String message;

  const PasswordResetSent({required this.message});

  @override
  List<Object?> get props => [message];
}

class RegistrationSuccess extends AuthState {
  final String message;

  const RegistrationSuccess({
    this.message = 'Registration successful! Please login.',
  });

  @override
  List<Object?> get props => [message];
}
