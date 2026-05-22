import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../models/user.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthState {
  final User? user;
  final bool isInitializing;
  final bool isLoading;
  final bool needsPassword;
  final String? error;
  final String? forcedLogoutMessage;

  const AuthState({
    this.user,
    this.isInitializing = false,
    this.isLoading = false,
    this.needsPassword = false,
    this.error,
    this.forcedLogoutMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isInitializing,
    bool? isLoading,
    bool? needsPassword,
    String? error,
    String? forcedLogoutMessage,
  }) => AuthState(
    user: user ?? this.user,
    isInitializing: isInitializing ?? this.isInitializing,
    isLoading: isLoading ?? this.isLoading,
    needsPassword: needsPassword ?? this.needsPassword,
    error: error,
    forcedLogoutMessage: forcedLogoutMessage,
  );

  AuthState clearError() => AuthState(
    user: user,
    isInitializing: isInitializing,
    isLoading: isLoading,
    needsPassword: needsPassword,
    forcedLogoutMessage: forcedLogoutMessage,
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState(isInitializing: true)) {
    _api.onUnauthorized = _forceLogout;
    _init();
  }

  Future<void> _forceLogout(String reason) async {
    await _api.clearToken();
    state = AuthState(forcedLogoutMessage: reason);
  }

  void consumeForcedLogoutMessage() {
    if (state.forcedLogoutMessage != null) {
      state = state.copyWith(forcedLogoutMessage: null);
    }
  }

  Future<void> _init() async {
    final token = await _api.getToken();
    if (token == null) {
      state = const AuthState();
      return;
    }
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.user);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      OneSignal.login(user.id.toString());
      state = AuthState(user: user);
    } catch (_) {
      await _api.clearToken();
      state = const AuthState();
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool remember = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      final token = res.data!['token'] as String;
      await _api.saveToken(token, remember: remember);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      OneSignal.login(user.id.toString());
      state = AuthState(user: user);
      return true;
    } on DioException catch (e) {
      final msg = _extractError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Нэвтрэх хариу буруу байна. Дахин оролдоно уу.',
      );
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );
      final token = res.data!['token'] as String;
      await _api.saveToken(token);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      state = AuthState(user: user);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: 'Бүртгэлийн хариу буруу байна. Дахин оролдоно уу.',
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.clearError();
    try {
      final googleUser = await GoogleSignIn(scopes: ['email', 'profile']).signIn();
      if (googleUser == null) {
        state = state.copyWith(error: 'Google нэвтрэлт цуцлагдлаа.');
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final fbUser = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseIdToken = await fbUser.user!.getIdToken();

      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.googleAuth,
        data: {'id_token': firebaseIdToken},
      );
      final token = res.data!['token'] as String;
      await _api.saveToken(token);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      final needsPassword = res.data!['needs_password'] as bool? ?? false;
      OneSignal.login(user.id.toString());
      state = AuthState(user: user, needsPassword: needsPassword);
      return true;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(error: 'Firebase: ${e.code} — ${e.message}');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    } catch (e) {
      final s = e.toString();
      state = state.copyWith(error: s.length > 120 ? s.substring(0, 120) : s);
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    state = state.clearError();
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );
      final fbUser = await fb.FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final firebaseIdToken = await fbUser.user!.getIdToken();

      final res = await _api.post<Map<String, dynamic>>(
        ApiEndpoints.appleAuth,
        data: {'id_token': firebaseIdToken},
      );
      final token = res.data!['token'] as String;
      await _api.saveToken(token);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      final needsPassword = res.data!['needs_password'] as bool? ?? false;
      OneSignal.login(user.id.toString());
      state = AuthState(user: user, needsPassword: needsPassword);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(error: 'Apple нэвтрэлт цуцлагдлаа.');
      } else {
        state = state.copyWith(error: 'Apple нэвтрэлт амжилтгүй: ${e.message}');
      }
      return false;
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(error: 'Firebase: ${e.code} — ${e.message}');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    } catch (e) {
      final s = e.toString();
      state = state.copyWith(error: s.length > 120 ? s.substring(0, 120) : s);
      return false;
    }
  }

  String _generateNonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  Future<bool> setPassword(String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post<dynamic>(
        ApiEndpoints.setPassword,
        data: {'password': password, 'password_confirmation': password},
      );
      state = state.copyWith(isLoading: false, needsPassword: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Нууц үг тохируулахад алдаа гарлаа.');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>(ApiEndpoints.logout);
    } catch (_) {}
    await _api.clearToken();
    OneSignal.logout();
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final res = await _api.get<Map<String, dynamic>>(ApiEndpoints.user);
      final user = User.fromJson(res.data!['user'] as Map<String, dynamic>);
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  String _extractError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      if (data['message'] != null) {
        return _translateServerMessage(data['message'].toString());
      }
      if (data['errors'] != null) {
        final errors = data['errors'] as Map;
        final message = errors.values.first is List
            ? (errors.values.first as List).first.toString()
            : errors.values.first.toString();
        return _translateServerMessage(message);
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      final text = data.trim();
      if (text.contains('personal_access_tokens') ||
          text.contains('Base table or view not found')) {
        return 'Серверийн өгөгдлийн сан шинэчлэгдээгүй байна.';
      }
      if (!text.startsWith('<!DOCTYPE') && !text.startsWith('<html')) {
        return text.length > 160 ? '${text.substring(0, 160)}...' : text;
      }
    }

    if (statusCode != null) {
      if (statusCode == 401) return 'И-мэйл эсвэл нууц үг буруу байна.';
      if (statusCode == 404) {
        return 'Нэвтрэх API олдсонгүй: ${e.requestOptions.uri}.';
      }
      if (statusCode >= 500) {
        return 'Серверийн алдаа $statusCode. Серверийн логийг шалгана уу.';
      }
      return 'Хүсэлт $statusCode төлөвтэй амжилтгүй боллоо.';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Холболтын хугацаа дууслаа. API хаягийг шалгана уу: ${e.requestOptions.baseUrl}';
      case DioExceptionType.connectionError:
        return 'API сервертэй холбогдож чадсангүй: ${e.requestOptions.baseUrl}';
      case DioExceptionType.badCertificate:
        return 'API SSL сертификат зөвшөөрөгдсөнгүй.';
      case DioExceptionType.cancel:
        return 'Нэвтрэх хүсэлт цуцлагдлаа.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return e.message ?? 'Сүлжээний алдаа. API хаягийг шалгана уу.';
    }
  }

  String _translateServerMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid credentials')) {
      return 'И-мэйл эсвэл нууц үг буруу байна.';
    }
    if (normalized.contains('unauthenticated')) {
      return 'Та дахин нэвтэрнэ үү.';
    }
    if (normalized.contains('email field is required')) {
      return 'И-мэйлээ оруулна уу.';
    }
    if (normalized.contains('password field is required')) {
      return 'Нууц үгээ оруулна уу.';
    }
    if (normalized.contains('email has already been taken')) {
      return 'Энэ и-мэйл бүртгэлтэй байна.';
    }
    return message;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(apiClientProvider)),
);
