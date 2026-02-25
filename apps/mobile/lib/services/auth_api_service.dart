import 'dart:convert';

import '../core/api_client.dart';

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
  const MfaEnrollmentRequiredResult({required this.refreshToken, this.message});
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

class PasswordChangeRequiredResult {
  const PasswordChangeRequiredResult({required this.refreshToken});
  final String refreshToken;
}

class AuthApiService {
  static Future<
    ({
      LoginApiResult? result,
      MfaEnrollmentRequiredResult? mfaEnrollmentRequired,
      MfaVerificationRequiredResult? mfaVerificationRequired,
      PasswordChangeRequiredResult? passwordChangeRequired,
      String? error,
      int statusCode,
    })
  >
  login({required String email, required String password}) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/login');
    final res = await ApiClient.client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(ApiClient.defaultTimeout);

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
            passwordChangeRequired: null,
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
          passwordChangeRequired: null,
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
            passwordChangeRequired: null,
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
          passwordChangeRequired: null,
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
          passwordChangeRequired: null,
          error: 'Respuesta inválida del servidor.',
          statusCode: 500,
        );
      }
      if (body['requires_password_change'] == true) {
        return (
          result: null,
          mfaEnrollmentRequired: null,
          mfaVerificationRequired: null,
          passwordChangeRequired: PasswordChangeRequiredResult(
            refreshToken: refreshToken,
          ),
          error: null,
          statusCode: res.statusCode,
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
        passwordChangeRequired: null,
        error: null,
        statusCode: res.statusCode,
      );
    }

    return (
      result: null,
      mfaEnrollmentRequired: null,
      mfaVerificationRequired: null,
      passwordChangeRequired: null,
      error: body['error'] as String?,
      statusCode: res.statusCode,
    );
  }

  static Future<({LoginApiResult? result, String? error, int statusCode})>
  mfaVerify({required String refreshToken, required String code}) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/mfa/verify');
    final res = await ApiClient.client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken, 'code': code}),
        )
        .timeout(ApiClient.defaultTimeout);
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

  static Future<
    ({
      String? factorId,
      String? qrCode,
      String? secret,
      String? error,
      int statusCode,
    })
  >
  mfaEnroll({required String refreshToken}) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/mfa/enroll');
    final res = await ApiClient.client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(ApiClient.defaultTimeout);
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
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/mfa/enroll-verify');
    final res = await ApiClient.client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'refresh_token': refreshToken,
            'factor_id': factorId,
            'code': code,
          }),
        )
        .timeout(ApiClient.defaultTimeout);
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

  static Future<({String? error, int statusCode})> forgotPassword({
    required String email,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/forgot-password');
    final res = await ApiClient.client
        .post(
          url,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'redirect_to': 'app'}),
        )
        .timeout(ApiClient.defaultTimeout);
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    if (res.statusCode == 200) {
      return (error: null, statusCode: res.statusCode);
    }
    return (
      error: body['error'] as String? ?? 'Error al enviar. Intentá de nuevo.',
      statusCode: res.statusCode,
    );
  }

  static Future<({String? error, int statusCode, String? refreshToken})>
  changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/change-password');
    final res = await ApiClient.client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }),
        )
        .timeout(ApiClient.defaultTimeout);
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    if (res.statusCode == 200) {
      final rt = body['refresh_token'] as String?;
      return (error: null, statusCode: res.statusCode, refreshToken: rt);
    }
    return (
      error: body['error'] as String? ?? 'Error al cambiar contraseña.',
      statusCode: res.statusCode,
      refreshToken: null,
    );
  }

  static Future<void> passwordSetComplete({required String token}) async {
    try {
      final url = Uri.parse(
        '${ApiClient.baseUrl}/api/v1/auth/password-set-complete',
      );
      await ApiClient.client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiClient.defaultTimeout);
    } catch (_) {
      // Non-critical: best effort
    }
  }

  static Future<({bool ok, String? error})> createInvite({
    required String email,
    String role = 'empleado',
    String? name,
    bool sendEmail = true,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) {
      return (ok: false, error: 'No hay sesión');
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/auth/invite');
    final body = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      'role': role,
      'send_email': sendEmail,
    };
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }

    final res = await ApiClient.client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiClient.inviteTimeout);

    final resBody = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};

    if (res.statusCode == 200 || res.statusCode == 201) {
      return (ok: true, error: null);
    }
    return (
      ok: false,
      error: resBody['error'] as String? ?? 'Error al enviar invitación',
    );
  }
}
