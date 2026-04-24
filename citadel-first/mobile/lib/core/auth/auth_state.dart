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
  final bool signupCompleted;
  const AuthAuthenticated({
    required this.userType,
    required this.userId,
    this.signupCompleted = true,
  });
  @override
  List<Object?> get props => [userType, userId, signupCompleted];
}

/// No valid token — show login screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}