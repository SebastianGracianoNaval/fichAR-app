import 'dart:convert';

import '../core/api_client.dart';

class DashboardKpis {
  const DashboardKpis({
    required this.totalEmpleados,
    required this.fichadosHoy,
    required this.alertasPendientes,
    required this.licenciasPendientes,
  });

  final int totalEmpleados;
  final int fichadosHoy;
  final int alertasPendientes;
  final int licenciasPendientes;

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return DashboardKpis(
      totalEmpleados: data['total_empleados'] as int? ?? 0,
      fichadosHoy: data['fichados_hoy'] as int? ?? 0,
      alertasPendientes: data['alertas_pendientes'] as int? ?? 0,
      licenciasPendientes: data['licencias_pendientes'] as int? ?? 0,
    );
  }
}

class DashboardApiService {
  static Future<({DashboardKpis? data, String? error})>
  getAdminDashboard() async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/admin/dashboard');
    final res = await ApiClient.client
        .get(url, headers: await ApiClient.authHeaders())
        .timeout(ApiClient.defaultTimeout);

    if (res.statusCode != 200) {
      final body = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
          : <String, dynamic>{};
      return (
        data: null,
        error: body['error'] as String? ?? 'Error al cargar panel',
      );
    }

    if (res.body.isEmpty) {
      return (data: null, error: 'Respuesta vacía del servidor');
    }

    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return (data: DashboardKpis.fromJson(body), error: null);
    } catch (_) {
      return (data: null, error: 'Respuesta inválida del servidor');
    }
  }
}
