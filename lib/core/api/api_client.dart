import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_endpoints.dart';

String get _currentPlatform {
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'web';
}

// Called when a non-login request gets a 401 — session was revoked.
typedef UnauthorizedCallback = void Function(String reason);

// Paths where a 401 is a normal credential error, not a revoked session.
const _authPaths = {'/auth/login', '/auth/register', '/auth/google', '/auth/apple'};

class ApiClient {
  static const _tokenKey = 'auth_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  String? _token;

  /// Set by AuthNotifier to handle session revocation.
  UnauthorizedCallback? onUnauthorized;

  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = Dio(
          BaseOptions(
            baseUrl: ApiEndpoints.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'X-Platform': _currentPlatform,
            },
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = _token ?? await _storage.read(key: _tokenKey);
          if (token != null) {
            _token = token;
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          if (status == 401 && !_authPaths.contains(path)) {
            final reason = _extractReason(error.response?.data);
            onUnauthorized?.call(reason);
          }
          handler.next(error);
        },
      ),
    );
  }

  static String _extractReason(dynamic data) {
    if (data is Map) {
      final msg = data['message']?.toString().toLowerCase() ?? '';
      if (msg.contains('device') || msg.contains('session') ||
          msg.contains('another') || msg.contains('terminated')) {
        return 'Таны акаунт өөр төхөөрөмж дээр нэвтэрсэн байна. Дахин нэвтэрнэ үү.';
      }
    }
    return 'Таны сеш дууссан байна. Дахин нэвтэрнэ үү.';
  }

  Future<void> saveToken(String token, {bool remember = true}) async {
    _token = token;
    if (remember) {
      await _storage.write(key: _tokenKey, value: token);
    } else {
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  Future<String?> getToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) =>
      _dio.post<T>(path, data: data, queryParameters: queryParameters);

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
  }) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {dynamic data}) =>
      _dio.delete<T>(path, data: data);
}
