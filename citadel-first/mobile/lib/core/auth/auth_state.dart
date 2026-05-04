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
  final String? name;
  final bool hasBeneficiaries;
  final int unreadNotificationCount;
  const AuthAuthenticated({
    required this.userType,
    required this.userId,
    this.signupCompleted = true,
    this.name,
    this.hasBeneficiaries = false,
    this.unreadNotificationCount = 0,
  });
  @override
  List<Object?> get props => [userType, userId, signupCompleted, name, hasBeneficiaries, unreadNotificationCount];
}

/// No valid token — show login screen.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}