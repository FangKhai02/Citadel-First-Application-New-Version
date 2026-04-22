import 'package:flutter_bloc/flutter_bloc.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../storage/secure_storage.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _api;

  AuthBloc({ApiClient? api})
      : _api = api ?? ApiClient(),
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginSucceeded>(_onLoginSucceeded);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      // Verify token is still valid by calling /users/me
      final res = await _api.get(ApiEndpoints.me);
      final userType = res.data['user_type'] as String;
      final userId = res.data['id'] as int;
      emit(AuthAuthenticated(userType: userType, userId: userId));
    } catch (_) {
      await SecureStorage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginSucceeded(
    AuthLoginSucceeded event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthAuthenticated(userType: event.userType, userId: event.userId));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _api.post(ApiEndpoints.logout);
    } finally {
      await SecureStorage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }
}
