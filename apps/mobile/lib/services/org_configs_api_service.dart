import 'dart:convert';

import '../core/api_client.dart';
import '../utils/error_utils.dart';

class OrgConfigItem {
  const OrgConfigItem({
    required this.key,
    required this.value,
    required this.type,
    this.options,
  });

  final String key;
  final dynamic value;
  final String type;
  final List<dynamic>? options;

  factory OrgConfigItem.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'] as List<dynamic>?;
    return OrgConfigItem(
      key: json['key'] as String? ?? '',
      value: json['value'],
      type: json['type'] as String? ?? 'string',
      options: optionsRaw,
    );
  }
}

class OrgConfigsApiService {
  static Future<({List<OrgConfigItem> data, String? error})>
  getConfigs() async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/org-configs');
    try {
      final res = await ApiClient.client
          .get(url, headers: await ApiClient.authHeaders())
          .timeout(ApiClient.defaultTimeout);

      if (res.statusCode != 200) {
        final body = res.body.isNotEmpty
            ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
            : <String, dynamic>{};
        return (
          data: <OrgConfigItem>[],
          error: body['error'] as String? ?? 'Error al cargar configuracion',
        );
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['data'] as List<dynamic>? ?? [];
      final List<OrgConfigItem> data = list
          .map((e) => OrgConfigItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return (data: data, error: null);
    } catch (e) {
      return (data: <OrgConfigItem>[], error: formatApiError(e));
    }
  }

  static Future<({bool ok, String? error})> patchConfigs(
    Map<String, dynamic> configs,
  ) async {
    final url = Uri.parse('${ApiClient.baseUrl}/api/v1/org-configs');
    try {
      final res = await ApiClient.client
          .patch(
            url,
            headers: await ApiClient.authHeaders(),
            body: jsonEncode({'configs': configs}),
          )
          .timeout(ApiClient.defaultTimeout);

      if (res.statusCode != 200) {
        final body = res.body.isNotEmpty
            ? (jsonDecode(res.body) as Map<String, dynamic>? ?? const {})
            : <String, dynamic>{};
        return (
          ok: false,
          error: body['error'] as String? ?? 'Error al guardar configuracion',
        );
      }
      return (ok: true, error: null);
    } catch (e) {
      return (ok: false, error: formatApiError(e));
    }
  }
}
