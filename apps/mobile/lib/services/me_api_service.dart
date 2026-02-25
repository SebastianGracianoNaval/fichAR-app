import 'dart:convert';

import '../core/api_client.dart';

class MeResult {
  const MeResult({
    required this.id,
    required this.orgId,
    required this.role,
    required this.email,
    this.name,
    this.cuil,
    this.orgName,
    this.requiresPasswordChange = false,
  });

  final String id;
  final String orgId;
  final String role;
  final String email;
  final String? name;
  final String? cuil;
  final String? orgName;
  final bool requiresPasswordChange;

  factory MeResult.fromJson(Map<String, dynamic> json) {
    return MeResult(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      role: json['role'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      cuil: json['cuil'] as String?,
      orgName: json['org_name'] as String?,
      requiresPasswordChange:
          json['requires_password_change'] as bool? ?? false,
    );
  }
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.current = false,
  });

  final String id;
  final String createdAt;
  final String updatedAt;
  final bool current;

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id'] as String,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      current: json['current'] as bool? ?? false,
    );
  }
}

class MeApiService {
  static const String sessionExpiredError = 'session_expired';

  static Future<({MeResult? result, String? error})> getMe() async {
    final token = await ApiClient.getToken();
    if (token == null) {
      return (result: null, error: sessionExpiredError);
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/me');
    final res = await ApiClient.client
        .get(url, headers: {'Authorization': 'Bearer $token'})
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode == 401) {
      return (result: null, error: sessionExpiredError);
    }
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        result: null,
        error: body['error'] as String? ?? 'Error al obtener usuario',
      );
    }

    if (res.body.isEmpty) {
      return (result: null, error: 'Respuesta vacía del servidor');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return (result: null, error: 'Respuesta inválida del servidor');
    }
    try {
      return (result: MeResult.fromJson(body), error: null);
    } catch (_) {
      return (result: null, error: 'Datos de usuario incompletos');
    }
  }

  static Future<({List<DeviceSession>? devices, String? error})>
  getDevices() async {
    final token = await ApiClient.getToken();
    if (token == null) {
      return (devices: null, error: sessionExpiredError);
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/me/devices');
    final res = await ApiClient.client
        .get(url, headers: {'Authorization': 'Bearer $token'})
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode == 401) {
      return (devices: null, error: sessionExpiredError);
    }
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        devices: null,
        error: body['error'] as String? ?? 'Error al obtener dispositivos',
      );
    }

    if (res.body.isEmpty) {
      return (devices: null, error: 'Respuesta vacía del servidor');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return (devices: null, error: 'Respuesta inválida del servidor');
    }

    final data = body['data'] as List<dynamic>? ?? [];
    try {
      final devices = data
          .map((e) => DeviceSession.fromJson(e as Map<String, dynamic>))
          .toList();
      return (devices: devices, error: null);
    } catch (_) {
      return (devices: null, error: 'Datos de dispositivos incompletos');
    }
  }

  static Future<({bool ok, String? error})> revokeDevice(
    String sessionId,
  ) async {
    final token = await ApiClient.getToken();
    if (token == null) {
      return (ok: false, error: 'No hay sesión activa');
    }

    final url = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/me/devices/$sessionId/revoke',
    );
    final res = await ApiClient.client
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        )
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (ok: false, error: body['error'] as String? ?? 'Error al revocar');
    }

    return (ok: true, error: null);
  }
}
