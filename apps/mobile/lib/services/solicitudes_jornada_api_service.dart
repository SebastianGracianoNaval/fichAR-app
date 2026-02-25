import 'dart:convert';

import '../core/api_client.dart';

class SolicitudJornada {
  const SolicitudJornada({
    required this.id,
    required this.tipo,
    required this.estado,
    required this.fechaSolicitud,
    this.fechaObjetivo,
    this.horasSolicitadas,
    this.horaDesde,
    this.horaHasta,
    this.motivoRechazo,
    this.createdAt,
    this.updatedAt,
    this.solicitanteNombre,
    this.estaVencida = false,
  });

  final String id;
  final String tipo;
  final String estado;
  final String fechaSolicitud;
  final String? fechaObjetivo;
  final double? horasSolicitadas;
  final String? horaDesde;
  final String? horaHasta;
  final String? motivoRechazo;
  final String? createdAt;
  final String? updatedAt;
  final String? solicitanteNombre;
  final bool estaVencida;

  static String? _timeToHHmm(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final h = parts[0].padLeft(2, '0');
      final m = parts[1].padLeft(2, '0');
      return '$h:$m';
    }
    return raw;
  }

  factory SolicitudJornada.fromJson(Map<String, dynamic> json) {
    final horas = json['horas_solicitadas'];
    final estaVencida = json['esta_vencida'] as bool? ?? false;
    final solicitanteNombre = json['solicitante_nombre'] as String?;
    return SolicitudJornada(
      id: json['id'] as String,
      tipo: json['tipo'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
      fechaSolicitud: json['fecha_solicitud'] as String? ?? '',
      fechaObjetivo: json['fecha_objetivo'] as String?,
      horasSolicitadas: horas is num ? horas.toDouble() : null,
      horaDesde: _timeToHHmm(json['hora_desde'] as String?),
      horaHasta: _timeToHHmm(json['hora_hasta'] as String?),
      motivoRechazo: json['motivo_rechazo'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      solicitanteNombre: solicitanteNombre,
      estaVencida: estaVencida,
    );
  }

  String get tipoLabel {
    switch (tipo) {
      case 'mas_horas':
        return 'Trabajar más';
      case 'menos_horas':
        return 'Trabajar menos';
      case 'intercambio':
        return 'Intercambio';
      default:
        return tipo;
    }
  }
}

class SolicitudesJornadaApiService {
  static Future<({List<SolicitudJornada> data, int total})> getSolicitudes({
    String? estado,
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (estado != null && estado.isNotEmpty) query['estado'] = estado;

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/solicitudes-jornada')
        .replace(queryParameters: query);
    final res = await ApiClient.client
        .get(url, headers: {'Authorization': 'Bearer $token'})
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>?
          : null;
      throw Exception(body?['error'] as String? ?? 'Error al listar solicitudes');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?)
            ?.map((e) => SolicitudJornada.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final total = body['meta']?['total'] as int? ?? data.length;
    return (data: data, total: total);
  }

  static Future<SolicitudJornada> create({
    required String tipo,
    String? fechaObjetivo,
    double? horasSolicitadas,
    String? horaDesde,
    String? horaHasta,
    String? employeeId,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final body = <String, dynamic>{'tipo': tipo};
    if (fechaObjetivo != null && fechaObjetivo.isNotEmpty) {
      body['fecha_objetivo'] = fechaObjetivo;
    }
    if (horasSolicitadas != null) {
      body['horas_solicitadas'] = horasSolicitadas;
    }
    if (horaDesde != null && horaDesde.isNotEmpty) body['hora_desde'] = horaDesde;
    if (horaHasta != null && horaHasta.isNotEmpty) body['hora_hasta'] = horaHasta;
    if (employeeId != null && employeeId.isNotEmpty) {
      body['employee_id'] = employeeId;
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/solicitudes-jornada');
    final res = await ApiClient.client
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 201) {
      final b = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>?
          : null;
      throw Exception(b?['error'] as String? ?? 'Error al crear solicitud');
    }

    return SolicitudJornada.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static Future<({bool ok, String? error})> patch({
    required String id,
    required String estado,
    String? motivoRechazo,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) return (ok: false, error: 'No hay sesión');

    final body = <String, dynamic>{'estado': estado};
    if (motivoRechazo != null && motivoRechazo.trim().isNotEmpty) {
      body['motivo_rechazo'] = motivoRechazo.trim();
    }

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/solicitudes-jornada/$id');
    final res = await ApiClient.client
        .patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode == 200) return (ok: true, error: null);
    final b = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>?
        : null;
    return (ok: false, error: b?['error'] as String? ?? 'Error al actualizar');
  }
}
