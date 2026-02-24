import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';

class LegalApiService {
  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getFichajes({
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
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/legal/fichajes',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  static Future<
    ({
      List<Map<String, dynamic>> data,
      int total,
      int limit,
      int offset,
      String? error,
    })
  >
  getAuditLogs({
    required String desde,
    required String hasta,
    String? action,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'desde': desde,
      'hasta': hasta,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (action != null && action.isNotEmpty) params['action'] = action;
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/legal/audit-logs',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseAuditLogsResponse(res);
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getLicencias({
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
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/legal/licencias',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getHashChain({
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
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/legal/hash-chain',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  static ({
    List<Map<String, dynamic>> data,
    int total,
    int limit,
    int offset,
    String? error,
  })
  _parseAuditLogsResponse(http.Response res) {
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        data: [],
        total: 0,
        limit: 50,
        offset: 0,
        error: body['error'] as String? ?? 'Error al obtener logs',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data =
        (body['data'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final meta = body['meta'] as Map<String, dynamic>?;
    return (
      data: data,
      total: meta?['total'] as int? ?? 0,
      limit: meta?['limit'] as int? ?? 50,
      offset: meta?['offset'] as int? ?? 0,
      error: null,
    );
  }

  static ({List<Map<String, dynamic>> data, int total, String? error})
  _parseListResponse(http.Response res) {
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
    final data =
        (body['data'] as List<dynamic>?)
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
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/legal/export');
    final body = {
      'tipo': tipo,
      'desde': desde,
      'hasta': hasta,
      'formato': formato,
      if (empleadoIds != null && empleadoIds.isNotEmpty)
        'empleado_ids': empleadoIds,
    };
    final res = await ApiClient.client
        .post(
          url,
          headers: await ApiClient.authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(ApiClient.exportTimeout);

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
