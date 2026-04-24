import 'package:equatable/equatable.dart';

abstract class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  final String userType;
  final int userId;
  final String accessToken;
  final String refreshToken;
  const LoginSuccess({
    required this.userType,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });
  @override
  List<Object?> get props => [userType, userId];
}

class LoginFailure extends LoginState {
  final String message;
  final bool emailNotRegistered;
  const LoginFailure(this.message, {this.emailNotRegistered = false});
  @override
  List<Object?> get props => [message, emailNotRegistered];
}