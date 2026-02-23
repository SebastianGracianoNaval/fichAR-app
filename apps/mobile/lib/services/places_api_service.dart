import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';

/// Admin place (lugar de trabajo). P-ADM-03.
class AdminPlace {
  const AdminPlace({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.lat,
    required this.long,
    required this.radioM,
    this.dias,
    this.createdAt,
  });

  final String id;
  final String nombre;
  final String direccion;
  final double lat;
  final double long;
  final int radioM;
  final List<String>? dias;
  final String? createdAt;

  factory AdminPlace.fromJson(Map<String, dynamic> json) {
    final diasRaw = json['dias'];
    List<String>? dias;
    if (diasRaw is List) {
      dias = diasRaw.map((e) => e.toString()).toList();
    } else if (diasRaw is String && diasRaw.isNotEmpty) {
      dias = diasRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return AdminPlace(
      id: json['id'] as String,
      nombre: json['nombre'] as String? ?? '',
      direccion: json['direccion'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      long: (json['long'] as num?)?.toDouble() ?? 0,
      radioM: (json['radio_m'] as num?)?.toInt() ?? 100,
      dias: dias,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'direccion': direccion,
        'lat': lat,
        'long': long,
        'radio_m': radioM,
        'dias': dias?.join(',') ?? 'L,M,X,J,V',
      };
}

class PlacesApiService {
  static Future<({List<AdminPlace> data, int total, int limit, int offset})> getPlaces({
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await ApiClient.authHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/places')
        .replace(queryParameters: {'limit': limit.toString(), 'offset': offset.toString()});
    final res = await ApiClient.client.get(url, headers: headers).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al listar lugares');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?)
            ?.map((e) => AdminPlace.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final meta = body['meta'] as Map<String, dynamic>?;
    final total = meta?['total'] as int? ?? data.length;
    final limitVal = meta?['limit'] as int? ?? limit;
    final offsetVal = meta?['offset'] as int? ?? offset;
    return (data: data, total: total, limit: limitVal, offset: offsetVal);
  }

  static Future<AdminPlace> createPlace({
    required String nombre,
    required String direccion,
    required double lat,
    required double long,
    int? radioM,
    required List<String> dias,
  }) async {
    final headers = await ApiClient.authHeaders();
    final body = jsonEncode({
      'nombre': nombre,
      'direccion': direccion,
      'lat': lat,
      'long': long,
      ...? (radioM != null ? {'radio_m': radioM} : null),
      'dias': dias.join(','),
    });
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/places');
    final res = await ApiClient.client.post(url, headers: headers, body: body).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 201) {
      final err = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(err?['error'] as String? ?? 'Error al crear lugar');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminPlace.fromJson(data);
  }

  static Future<AdminPlace> updatePlace(
    String id, {
    String? nombre,
    String? direccion,
    double? lat,
    double? long,
    int? radioM,
    List<String>? dias,
  }) async {
    final headers = await ApiClient.authHeaders();
    final updates = <String, dynamic>{};
    if (nombre != null) updates['nombre'] = nombre;
    if (direccion != null) updates['direccion'] = direccion;
    if (lat != null) updates['lat'] = lat;
    if (long != null) updates['long'] = long;
    if (radioM != null) updates['radio_m'] = radioM;
    if (dias != null) updates['dias'] = dias.join(',');
    if (updates.isEmpty) throw Exception('Nada que actualizar');

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/places/$id');
    final res = await ApiClient.client
        .patch(url, headers: headers, body: jsonEncode(updates))
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final err = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(err?['error'] as String? ?? 'Error al actualizar lugar');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return AdminPlace.fromJson(data);
  }

  static Future<({int imported, List<({int row, String reason})> errors})> importPlaces(
    List<int> bytes,
    String filename,
  ) async {
    final headers = await ApiClient.authHeaders();
    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/places/import');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({'Authorization': headers['Authorization']!})
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));
    final streamed = await request.send().timeout(ApiClient.defaultTimeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      final err = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(err?['error'] as String? ?? 'Error al importar lugares');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final imported = body['imported'] as int? ?? 0;
    final errorsRaw = body['errors'] as List<dynamic>? ?? [];
    final errors = errorsRaw
        .map((e) => (
              row: (e as Map<String, dynamic>)['row'] as int,
              reason: (e['reason'] as String?) ?? '',
            ))
        .toList();
    return (imported: imported, errors: errors);
  }

  static Future<void> deletePlace(String id) async {
    final headers = await ApiClient.authHeaders();
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/places/$id');
    final res = await ApiClient.client.delete(url, headers: headers).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final err = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(err?['error'] as String? ?? 'Error al eliminar lugar');
    }
  }
}
