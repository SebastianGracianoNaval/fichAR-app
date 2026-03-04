import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';

/// Result of uploading one adjunto for a licencia (CL-016, CL-017).
class LicenciaAdjuntoUpload {
  const LicenciaAdjuntoUpload({
    required this.storagePath,
    this.filename,
    this.mimeType,
  });
  final String storagePath;
  final String? filename;
  final String? mimeType;

  Map<String, String> toJson() {
    final m = <String, String>{'storage_path': storagePath};
    if (filename != null) m['filename'] = filename!;
    if (mimeType != null) m['mime_type'] = mimeType!;
    return m;
  }
}

class LicenciasApiService {
  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getLicencias({
    String? employeeId,
    String? estado,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (employeeId != null) params['employee_id'] = employeeId;
    if (estado != null) params['estado'] = estado;
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/licencias',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getLicenciasPendientes() async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/licencias/pendientes');
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  /// Upload one file for a licencia adjunto. Validates 5 MB, PDF/JPG/PNG (CL-017).
  /// Returns storage_path + filename + mime_type to pass to createLicencia.
  static Future<({LicenciaAdjuntoUpload? data, String? error})> uploadAdjunto(
    List<int> fileBytes, {
    required String filename,
    String? mimeType,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/licencias/upload');
    final token = await ApiClient.getToken();
    if (token == null) return (data: null, error: 'No hay sesión activa');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
    ));
    final streamed = await request.send().timeout(ApiClient.defaultTimeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        data: null,
        error: body['error'] as String? ?? 'Error al subir el archivo',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      data: LicenciaAdjuntoUpload(
        storagePath: body['storage_path'] as String,
        filename: body['filename'] as String?,
        mimeType: body['mime_type'] as String?,
      ),
      error: null,
    );
  }

  static Future<({Map<String, dynamic>? data, String? error})> createLicencia({
    required String tipo,
    required String fechaInicio,
    required String fechaFin,
    String? motivo,
    List<Map<String, String>>? adjuntos,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/licencias');
    final body = {
      'tipo': tipo,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      if (adjuntos != null && adjuntos.isNotEmpty) 'adjuntos': adjuntos,
    };
    final res = await ApiClient.client
        .post(
          url,
          headers: await ApiClient.authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(ApiClient.defaultTimeout);
    return _parseSingleResponse(res);
  }

  static Future<({bool ok, String? error})> aprobarLicencia(
    String licenciaId,
  ) async {
    final url = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/licencias/$licenciaId/aprobar',
    );
    final res = await ApiClient.client
        .post(url, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    if (res.statusCode == 200) return (ok: true, error: null);
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    return (
      ok: false,
      error: body['error'] as String? ?? 'Error al aprobar licencia',
    );
  }

  static Future<({bool ok, String? error})> rechazarLicencia(
    String licenciaId,
    String motivo,
  ) async {
    final url = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/licencias/$licenciaId/rechazar',
    );
    final res = await ApiClient.client
        .post(
          url,
          headers: await ApiClient.authHeaders(),
          body: jsonEncode({'motivo': motivo}),
        )
        .timeout(ApiClient.defaultTimeout);
    if (res.statusCode == 200) return (ok: true, error: null);
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    return (
      ok: false,
      error: body['error'] as String? ?? 'Error al rechazar licencia',
    );
  }

  static Future<({List<Map<String, dynamic>> data, int total, String? error})>
  getAlertas({
    String? tipo,
    String? employeeId,
    String? desde,
    String? hasta,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (tipo != null) params['tipo'] = tipo;
    if (employeeId != null) params['employee_id'] = employeeId;
    if (desde != null) params['desde'] = desde;
    if (hasta != null) params['hasta'] = hasta;
    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/alertas',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    return _parseListResponse(res);
  }

  static Future<({double saldoHoras, String? error})> getBanco() async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/banco');
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        saldoHoras: 0.0,
        error: body['error'] as String? ?? 'Error al obtener banco de horas',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final saldo = (body['saldo_horas'] as num?)?.toDouble() ?? 0.0;
    return (saldoHoras: saldo, error: null);
  }

  static Future<({List<Map<String, dynamic>> data, String? error})>
  getBancoEquipo() async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/banco/equipo');
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);
    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        data: <Map<String, dynamic>>[],
        error: body['error'] as String? ?? 'Error al obtener banco del equipo',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = body['data'] as List<dynamic>?;
    final data =
        raw
            ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList() ??
        <Map<String, dynamic>>[];
    return (data: data, error: null);
  }

  static Future<({List<int> bytes, String? error})> exportReporte({
    required String tipo,
    required String fechaDesde,
    required String fechaHasta,
    List<String>? empleadoIds,
    required String formato,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/reportes/export');
    final body = {
      'tipo': tipo,
      'fecha_desde': fechaDesde,
      'fecha_hasta': fechaHasta,
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
        error: resBody['error'] as String? ?? 'Error al exportar',
      );
    }
    return (bytes: res.bodyBytes, error: null);
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

  static ({Map<String, dynamic>? data, String? error}) _parseSingleResponse(
    http.Response res,
  ) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      return (data: body ?? {}, error: null);
    }
    final body = res.body.isNotEmpty
        ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
        : <String, dynamic>{};
    return (
      data: null,
      error: body['error'] as String? ?? 'Error al procesar solicitud',
    );
  }
}
