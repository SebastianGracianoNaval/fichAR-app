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
    this.motivoRechazo,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tipo;
  final String estado;
  final String fechaSolicitud;
  final String? fechaObjetivo;
  final double? horasSolicitadas;
  final String? motivoRechazo;
  final String? createdAt;
  final String? updatedAt;

  factory SolicitudJornada.fromJson(Map<String, dynamic> json) {
    final horas = json['horas_solicitadas'];
    return SolicitudJornada(
      id: json['id'] as String,
      tipo: json['tipo'] as String? ?? '',
      estado: json['estado'] as String? ?? 'pendiente',
      fechaSolicitud: json['fecha_solicitud'] as String? ?? '',
      fechaObjetivo: json['fecha_objetivo'] as String?,
      horasSolicitadas: horas is num ? horas.toDouble() : null,
      motivoRechazo: json['motivo_rechazo'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
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
