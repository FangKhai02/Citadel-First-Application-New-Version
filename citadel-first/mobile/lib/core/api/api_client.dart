import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  Dio _dio = _buildDio();

  Dio get dio => _dio;

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(_AuthInterceptor(dio));
    return dio;
  }

  void rebuild() {
    _dio = _buildDio();
  }

  // Convenience methods
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> get(String path) => _dio.get(path);
  Future<Response> patch(String path, {dynamic data}) => _dio.patch(path, data: data);
  Future<Response> put(String path, {dynamic data, Options? options}) => _dio.put(path, data: data, options: options);
  Future<Response> delete(String path) => _dio.delete(path);
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  _AuthInterceptor(this.dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Auto-refresh on 401
    if (err.response?.statusCode == 401) {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final res = await dio.post(
            ApiEndpoints.refresh,
            data: {'refresh_token': refreshToken},
          );
          final newAccess = res.data['access_token'] as String;
          final newRefresh = res.data['refresh_token'] as String;
          final userType = res.data['user_type'] as String;
          final userId = res.data['user_id'] as int;

          await SecureStorage.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
            userType: userType,
            userId: userId,
          );

          // Retry original request with new token
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          final retry = await dio.fetch(err.requestOptions);
          return handler.resolve(retry);
        } catch (_) {
          // Refresh failed — clear tokens so splash screen redirects to login
          await SecureStorage.clearAll();
        }
      }
    }
    handler.next(err);
  }
}