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
      final res = await _api.get(ApiEndpoints.me);
      final userType = res.data['user_type'] as String;
      final userId = res.data['id'] as int;
      final signupCompleted = res.data['signup_completed'] as bool? ?? true;
      final emailVerified = res.data['email_verified'] as bool? ?? true;
      final name = res.data['name'] as String?;
      final hasBeneficiaries = res.data['has_beneficiaries'] as bool? ?? false;
      final unreadNotificationCount = res.data['unread_notification_count'] as int? ?? 0;

      if (!signupCompleted) {
        // Incomplete signup — clean up and force re-registration
        try {
          await _api.delete(ApiEndpoints.incompleteSignup);
        } catch (_) {}
        await SecureStorage.clearAll();
        emit(const AuthUnauthenticated());
        return;
      }

      if (!emailVerified) {
        // Email not verified — clear tokens and redirect to login
        await SecureStorage.clearAll();
        emit(const AuthUnauthenticated());
        return;
      }

      emit(AuthAuthenticated(
        userType: userType,
        userId: userId,
        signupCompleted: signupCompleted,
        name: name,
        hasBeneficiaries: hasBeneficiaries,
        unreadNotificationCount: unreadNotificationCount,
      ));
    } catch (_) {
      await SecureStorage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginSucceeded(
    AuthLoginSucceeded event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthAuthenticated(
      userType: event.userType,
      userId: event.userId,
      name: event.name,
      hasBeneficiaries: event.hasBeneficiaries,
    ));
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