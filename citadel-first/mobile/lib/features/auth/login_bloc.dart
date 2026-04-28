import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/storage/secure_storage.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final ApiClient _api;

  LoginBloc({ApiClient? api})
      : _api = api ?? ApiClient(),
        super(const LoginInitial()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(const LoginLoading());
    try {
      final res = await _api.post(
        ApiEndpoints.login,
        data: {'email': event.email, 'password': event.password},
      );

      final accessToken = res.data['access_token'] as String;
      final refreshToken = res.data['refresh_token'] as String;
      final userType = res.data['user_type'] as String;
      final userId = res.data['user_id'] as int;

      await SecureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userType: userType,
        userId: userId,
        email: event.email,
      );

      emit(LoginSuccess(
        userType: userType,
        userId: userId,
        accessToken: accessToken,
        refreshToken: refreshToken,
      ));
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail']?.toString() ??
          'Login failed. Please try again.';

      if (statusCode == 404) {
        emit(LoginFailure(detail, emailNotRegistered: true));
      } else if (statusCode == 403) {
        emit(LoginFailure(detail, emailNotVerified: true));
      } else {
        emit(LoginFailure(detail));
      }
    } catch (_) {
      emit(const LoginFailure('An unexpected error occurred.'));
    }
  }
}