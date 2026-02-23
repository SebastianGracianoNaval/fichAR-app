import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_client.dart';

class Employee {
  const Employee({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.status,
    this.branchId,
    this.supervisorId,
    this.modalidad,
    this.fechaIngreso,
    this.fechaEgreso,
    this.placeIds,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final String status;
  final String? branchId;
  final String? supervisorId;
  final String? modalidad;
  final String? fechaIngreso;
  final String? fechaEgreso;
  final List<String>? placeIds;

  factory Employee.fromJson(Map<String, dynamic> json) {
    final placeIdsRaw = json['place_ids'];
    List<String>? placeIds;
    if (placeIdsRaw is List) {
      placeIds = placeIdsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return Employee(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'empleado',
      status: json['status'] as String? ?? 'activo',
      branchId: json['branch_id'] as String?,
      supervisorId: json['supervisor_id'] as String?,
      modalidad: json['modalidad'] as String?,
      fechaIngreso: json['fecha_ingreso'] as String?,
      fechaEgreso: json['fecha_egreso'] as String?,
      placeIds: placeIds,
    );
  }
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    this.address,
  });

  final String id;
  final String name;
  final String? address;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      address: json['address'] as String?,
    );
  }
}

class EmployeesApiService {

  static Future<({List<Employee> data, int total})> getEmployees({
    String? branchId,
    String status = 'activo',
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final query = <String, String>{
      'status': status,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (branchId != null) query['branch_id'] = branchId;

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/employees').replace(queryParameters: query);
    final res = await ApiClient.client.get(url, headers: {'Authorization': 'Bearer $token'}).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al listar empleados');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] as List<dynamic>?)
            ?.map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final total = body['meta']?['total'] as int? ?? data.length;
    return (data: data, total: total);
  }

  static Future<Employee> getEmployee(String id) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/employees/$id');
    final res = await ApiClient.client.get(url, headers: {'Authorization': 'Bearer $token'}).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al obtener empleado');
    }

    return Employee.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> patchEmployee(
    String id, {
    String? role,
    String? branchId,
    String? supervisorId,
    String? modalidad,
    List<String>? placeIds,
  }) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (branchId != null) body['branch_id'] = branchId;
    if (supervisorId != null) body['supervisor_id'] = supervisorId;
    if (modalidad != null) body['modalidad'] = modalidad;
    if (placeIds != null) body['place_ids'] = placeIds;
    if (body.isEmpty) throw Exception('Nada que actualizar');

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/employees/$id');
    final res = await ApiClient.client.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final err = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(err?['error'] as String? ?? 'Error al actualizar empleado');
    }
  }

  static Future<void> offboardEmployee(String id, String fechaEgreso, {String? motivo}) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/employees/$id/offboard');
    final res = await ApiClient.client.post(
      url,
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'fecha_egreso': fechaEgreso, ...?motivo != null ? {'motivo': motivo} : null}),
    ).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al dar de baja');
    }
  }

  static Future<({int imported, List<Map<String, dynamic>> errors})> importEmployees(List<int> fileBytes, String filename) async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final uri = Uri.parse('${ApiClient.baseUrl}/api/v1/employees/import');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

    final streamed = await request.send().timeout(ApiClient.exportTimeout);
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al importar');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final imported = body['imported'] as int? ?? 0;
    final errors = (body['errors'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];
    return (imported: imported, errors: errors);
  }

  static Future<List<Branch>> getBranches() async {
    final token = await ApiClient.getToken();
    if (token == null) throw Exception('No hay sesión');

    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/branches');
    final res = await ApiClient.client.get(url, headers: {'Authorization': 'Bearer $token'}).timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic>? : null;
      throw Exception(body?['error'] as String? ?? 'Error al listar sucursales');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
  }
}
