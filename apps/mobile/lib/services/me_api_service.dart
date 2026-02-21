import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class MeResult {
  const MeResult({
    required this.id,
    required this.orgId,
    required this.role,
    required this.email,
  });

  final String id;
  final String orgId;
  final String role;
  final String email;

  factory MeResult.fromJson(Map<String, dynamic> json) {
    return MeResult(
      id: json['id'] as String,
      orgId: json['org_id'] as String,
      role: json['role'] as String,
      email: json['email'] as String? ?? '',
    );
  }
}

class MeApiService {
  static String _apiBaseUrl() {
    final apiUrl = dotenv.env['API_URL']?.trim();
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL no configurado en assets/.env');
    }
    return apiUrl;
  }

  static Future<({MeResult? result, String? error})> getMe() async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) {
      return (result: null, error: 'No hay sesión activa');
    }

    final url = Uri.parse('${_apiBaseUrl()}/api/v1/me');
    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

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
