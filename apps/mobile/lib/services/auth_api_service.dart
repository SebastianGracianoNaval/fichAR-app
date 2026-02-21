import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class LoginApiResult {
  const LoginApiResult({
    required this.token,
    required this.refreshToken,
    this.expiresIn,
  });

  final String token;
  final String refreshToken;
  final int? expiresIn;
}

class MfaEnrollmentRequiredResult {
  const MfaEnrollmentRequiredResult({
    required this.refreshToken,
    this.message,
  });
  final String refreshToken;
  final String? message;
}

class MfaVerificationRequiredResult {
  const MfaVerificationRequiredResult({
    required this.refreshToken,
    this.factorId,
    this.message,
  });
  final String refreshToken;
  final String? factorId;
  final String? message;
}

class AuthApiService {
  static String _apiBaseUrl() {
    final apiUrl = dotenv.env['API_URL']?.trim();
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL no configurado en assets/.env');
    }
    return apiUrl;
  }

  static Future<({
    LoginApiResult? result,
    MfaEnrollmentRequiredResult? mfaEnrollmentRequired,
    MfaVerificationRequiredResult? mfaVerificationRequired,
    String? error,
    int statusCode,
  })> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${_apiBaseUrl()}/api/v1/auth/login');
    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    Map<String, dynamic> body = const {};
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        body = const {};
      }
    }

    if (res.statusCode == 200) {
      if (body['requires_mfa_enrollment'] == true) {
        final rt = body['refresh_token'] as String?;
        if (rt == null) {
          return (
            result: null,
            mfaEnrollmentRequired: null,
            mfaVerificationRequired: null,
            error: 'Respuesta inválida del servidor.',
            statusCode: 500,
          );
        }
        return (
          result: null,
          mfaEnrollmentRequired: MfaEnrollmentRequiredResult(
            refreshToken: rt,
            message: body['message'] as String?,
          ),
          mfaVerificationRequired: null,
          error: null,
          statusCode: res.statusCode,
        );
      }
      if (body['requires_mfa_verification'] == true) {
        final rt = body['refresh_token'] as String?;
        if (rt == null) {
          return (
            result: null,
            mfaEnrollmentRequired: null,
            mfaVerificationRequired: null,
            error: 'Respuesta inválida del servidor.',
            statusCode: 500,
          );
        }
        return (
          result: null,
          mfaEnrollmentRequired: null,
          mfaVerificationRequired: MfaVerificationRequiredResult(
            refreshToken: rt,
            factorId: body['factor_id'] as String?,
            message: body['message'] as String?,
          ),
          error: null,
          statusCode: res.statusCode,
        );
      }
      final token = body['token'] as String?;
      final refreshToken = body['refresh_token'] as String?;
      if (token == null || refreshToken == null) {
        return (
          result: null,
          mfaEnrollmentRequired: null,
          mfaVerificationRequired: null,
          error: 'Respuesta inválida del servidor.',
          statusCode: 500,
        );
      }
      return (
        result: LoginApiResult(
          token: token,
          refreshToken: refreshToken,
          expiresIn: body['expires_in'] as int?,
        ),
        mfaEnrollmentRequired: null,
        mfaVerificationRequired: null,
        error: null,
        statusCode: res.statusCode,
      );
    }

    return (
      result: null,
      mfaEnrollmentRequired: null,
      mfaVerificationRequired: null,
      error: body['error'] as String?,
      statusCode: res.statusCode,
    );
  }

  static Future<({LoginApiResult? result, String? error, int statusCode})>
      mfaVerify({
    required String refreshToken,
    required String code,
  }) async {
    final url = Uri.parse('${_apiBaseUrl()}/api/v1/auth/mfa/verify');
    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken, 'code': code}),
    );
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    if (res.statusCode == 200) {
      final token = body['token'] as String?;
      final rt = body['refresh_token'] as String?;
      if (token == null || rt == null) {
        return (result: null, error: 'Respuesta inválida', statusCode: 500);
      }
      return (
        result: LoginApiResult(
          token: token,
          refreshToken: rt,
          expiresIn: body['expires_in'] as int?,
        ),
        error: null,
        statusCode: res.statusCode,
      );
    }
    return (
      result: null,
      error: body['error'] as String? ?? 'Error al verificar',
      statusCode: res.statusCode,
    );
  }

  static Future<({
    String? factorId,
    String? qrCode,
    String? secret,
    String? error,
    int statusCode,
  })> mfaEnroll({required String refreshToken}) async {
    final url = Uri.parse('${_apiBaseUrl()}/api/v1/auth/mfa/enroll');
    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    if (res.statusCode == 200) {
      return (
        factorId: body['factor_id'] as String?,
        qrCode: body['qr_code'] as String?,
        secret: body['secret'] as String?,
        error: null,
        statusCode: res.statusCode,
      );
    }
    return (
      factorId: null,
      qrCode: null,
      secret: null,
      error: body['error'] as String? ?? 'Error al configurar 2FA',
      statusCode: res.statusCode,
    );
  }

  static Future<({LoginApiResult? result, String? error, int statusCode})>
      mfaEnrollVerify({
    required String refreshToken,
    required String factorId,
    required String code,
  }) async {
    final url = Uri.parse('${_apiBaseUrl()}/api/v1/auth/mfa/enroll-verify');
    final res = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'refresh_token': refreshToken,
        'factor_id': factorId,
        'code': code,
      }),
    );
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    if (res.statusCode == 200) {
      final token = body['token'] as String?;
      final rt = body['refresh_token'] as String?;
      if (token == null || rt == null) {
        return (result: null, error: 'Respuesta inválida', statusCode: 500);
      }
      return (
        result: LoginApiResult(
          token: token,
          refreshToken: rt,
          expiresIn: body['expires_in'] as int?,
        ),
        error: null,
        statusCode: res.statusCode,
      );
    }
    return (
      result: null,
      error: body['error'] as String? ?? 'Código incorrecto',
      statusCode: res.statusCode,
    );
  }
}
