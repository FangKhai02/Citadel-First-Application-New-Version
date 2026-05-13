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
  final String? name;
  final bool hasBeneficiaries;
  const LoginSuccess({
    required this.userType,
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    this.name,
    this.hasBeneficiaries = false,
  });
  @override
  List<Object?> get props => [userType, userId, name, hasBeneficiaries];
}

class LoginFailure extends LoginState {
  final String message;
  final bool emailNotRegistered;
  final bool emailNotVerified;
  const LoginFailure(this.message, {this.emailNotRegistered = false, this.emailNotVerified = false});
  @override
  List<Object?> get props => [message, emailNotRegistered, emailNotVerified];
}