import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

/// Initial state — splash screen shows while checking.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Token valid — user is logged in.
class AuthAuthenticated extends AuthState {
  final String userType; // CLIENT | AGENT | CORPORATE | ADMIN
  final int userId;
  const AuthAuthenticated({required this.userType, required this.userId});
  @override
  List<Object?> get props => [userType, userId];
}

/// No valid token — show login screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}
