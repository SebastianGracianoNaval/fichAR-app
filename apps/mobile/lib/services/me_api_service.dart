import 'dart:convert';

import '../core/api_client.dart';

class MeResult {
  const MeResult({
    required this.id,
    required this.orgId,
    required this.role,
    required this.email,
    this.requiresPasswordChange = false,
  });

  final String id;
  final String orgId;
  final String role;
  final String email;
  final bool requiresPasswordChange;

  factory MeResult.fromJson(Map<String, dynamic> json) {
    return MeResult(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      role: json['role'] as String,
      email: json['email'] as String? ?? '',
      requiresPasswordChange: json['requires_password_change'] as bool? ?? false,
    );
  }
}

class MeApiService {
  static Future<({MeResult? result, String? error})> getMe() async {
    final token = await ApiClient.getToken();
    if (token == null) {
      return (result: null, error: 'No hay sesión activa');
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/me');
    final res = await ApiClient.client.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        result: null,
        error: body['error'] as String? ?? 'Error al obtener usuario',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (result: MeResult.fromJson(body), error: null);
  }
}
