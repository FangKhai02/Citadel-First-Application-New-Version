import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// Fired by splash screen to check stored token validity.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Fired after successful login to record auth state.
class AuthLoginSucceeded extends AuthEvent {
  final String userType;
  final int userId;
  final String? name;
  final bool hasBeneficiaries;
  const AuthLoginSucceeded({required this.userType, required this.userId, this.name, this.hasBeneficiaries = false});
  @override
  List<Object?> get props => [userType, userId, name, hasBeneficiaries];
}

/// Fired when user taps logout.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
