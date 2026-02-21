import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class LegalApiService {
  static String _apiBaseUrl() {
    final apiUrl = dotenv.env['API_URL']?.trim();
    if (apiUrl == null || apiUrl.isEmpty) {
      throw Exception('API_URL no configurado en assets/.env');
    }
    return apiUrl;
  }

  static Future<String?> _getToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    if (token == null) throw Exception('No hay sesión activa');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})> getFichajes({
    required String desde,
    required String hasta,
    String? empleadoId,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'desde': desde,
      'hasta': hasta,
      'limit': limit.toString(),
    };
    if (empleadoId != null) params['empleado_id'] = empleadoId;
    final uri = Uri.parse('${_apiBaseUrl()}/api/v1/legal/fichajes').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    return _parseListResponse(res);
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})> getAuditLogs({
    required String desde,
    required String hasta,
    String? action,
    int limit = 50,
  }) async {
    var uri = Uri.parse('${_apiBaseUrl()}/api/v1/legal/audit-logs').replace(
      queryParameters: {
        'desde': desde,
        'hasta': hasta,
        'limit': limit.toString(),
        if (action != null && action.isNotEmpty) 'action': action,
      },
    );
    final res = await http.get(uri, headers: await _headers());
    return _parseListResponse(res);
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})> getHashChain({
    required String desde,
    required String hasta,
    String? empleadoId,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'desde': desde,
      'hasta': hasta,
      'limit': limit.toString(),
    };
    if (empleadoId != null) params['empleado_id'] = empleadoId;
    final uri = Uri.parse('${_apiBaseUrl()}/api/v1/legal/hash-chain').replace(queryParameters: params);
    final res = await http.get(uri, headers: await _headers());
    return _parseListResponse(res);
  }

  static ({List<Map<String, dynamic>> data, int total, String? error}) _parseListResponse(
    http.Response res,
  ) {
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        data: [],
        total: 0,
        error: body['error'] as String? ?? 'Error al obtener datos',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final meta = body['meta'] as Map<String, dynamic>?;
    final total = meta?['total'] as int? ?? 0;
    return (data: data, total: total, error: null);
  }

  static Future<({List<int> bytes, String? sha256, String? error})> export({
    required String tipo,
    required String desde,
    required String hasta,
    List<String>? empleadoIds,
    required String formato,
  }) async {
    final url = Uri.parse('${_apiBaseUrl()}/api/v1/legal/export');
    final body = {
      'tipo': tipo,
      'desde': desde,
      'hasta': hasta,
      'formato': formato,
      if (empleadoIds != null && empleadoIds.isNotEmpty) 'empleado_ids': empleadoIds,
    };
    final res = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      final resBody = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        bytes: <int>[],
        sha256: null,
        error: resBody['error'] as String? ?? 'Error al exportar',
      );
    }

    final sha256 = res.headers['x-export-sha256'];
    return (bytes: res.bodyBytes, sha256: sha256, error: null);
  }
}
