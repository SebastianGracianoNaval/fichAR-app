import 'dart:convert';

import '../core/api_client.dart';

class Fichaje {
  const Fichaje({
    required this.id,
    required this.tipo,
    required this.timestampServidor,
    this.timestampDispositivo,
    this.lugarId,
    this.lat,
    this.long,
    this.hashRegistro,
  });

  final String id;
  final String tipo;
  final String timestampServidor;
  final String? timestampDispositivo;
  final String? lugarId;
  final double? lat;
  final double? long;
  final String? hashRegistro;

  factory Fichaje.fromJson(Map<String, dynamic> json) {
    return Fichaje(
      id: json['id'] as String,
      tipo: json['tipo'] as String,
      timestampServidor: json['timestamp_servidor'] as String,
      timestampDispositivo: json['timestamp_dispositivo'] as String?,
      lugarId: json['lugar_id'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      long: (json['long'] as num?)?.toDouble(),
      hashRegistro: json['hash_registro'] as String?,
    );
  }
}

class Place {
  const Place({
    required this.id,
    required this.nombre,
    this.lat,
    this.long,
    this.radioM,
    this.direccion,
  });

  final String id;
  final String nombre;
  final double? lat;
  final double? long;
  final int? radioM;
  final String? direccion;

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      long: (json['long'] as num?)?.toDouble(),
      radioM: json['radio_m'] as int?,
      direccion: json['direccion'] as String?,
    );
  }
}

class FichajesApiService {
  static Future<({Fichaje? fichaje, String? error, String? code})> postFichaje({
    required String tipo,
    double? lat,
    double? long,
    String? lugarId,
    String? idempotencyKey,
  }) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/fichajes');
    final body = {
      'tipo': tipo,
      'lat': ?lat,
      'long': ?long,
      'lugar_id': ?lugarId,
      'idempotency_key': ?idempotencyKey,
    };

    final res = await ApiClient.withRetry(() async {
      return await ApiClient.client
          .post(
            url,
            headers: await ApiClient.authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiClient.defaultTimeout);
    });

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return (fichaje: Fichaje.fromJson(data), error: null, code: null);
    }
    final err = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>?
        : null;
    return (
      fichaje: null,
      error: err?['error'] as String? ?? 'Error al registrar fichaje',
      code: err?['code'] as String?,
    );
  }

  static Future<({List<Fichaje> data, int total, String? error})> getFichajes({
    String? desde,
    String? hasta,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (desde != null) params['desde'] = desde;
    if (hasta != null) params['hasta'] = hasta;

    final uri = Uri.parse(
      '${ApiClient.baseUrl}/api/v1/fichajes',
    ).replace(queryParameters: params);
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>?
          : null;
      return (
        data: <Fichaje>[],
        total: 0,
        error: body?['error'] as String? ?? 'Error al listar fichajes',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = body['data'] as List<dynamic>? ?? [];
    final data = raw
        .map((e) => Fichaje.fromJson(e as Map<String, dynamic>))
        .toList();
    final total =
        (body['meta'] as Map<String, dynamic>?)?['total'] as int? ??
        data.length;
    return (data: data, total: total, error: null);
  }

  static Future<({List<Place> data, String? error})> getPlaces() async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/places');
    final res = await ApiClient.client
        .get(uri, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>?
          : null;
      return (
        data: <Place>[],
        error: body?['error'] as String? ?? 'Error al listar lugares',
      );
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = body['data'] as List<dynamic>? ?? [];
    final data = raw
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
    return (data: data, error: null);
  }
}
