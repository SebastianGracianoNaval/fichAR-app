import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../services/fichajes_api_service.dart';
import 'api_client.dart';

/// Persistent queue for offline fichajes. Stores encrypted via flutter_secure_storage.
/// CFG-009: when offline mode is enabled, fichajes are queued locally.
/// SEGURIDAD 6.2: offline data must be encrypted at rest.
class OfflineQueue {
  static const _storageKey = 'fichajes_pendientes';
  static const _legacyFileName = 'fichajes_pendientes.json';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Migrate from legacy plaintext file if it exists.
  static Future<void> _migrateLegacyIfNeeded() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final legacyFile = File('${dir.path}/$_legacyFileName');
      if (await legacyFile.exists()) {
        final content = await legacyFile.readAsString();
        if (content.isNotEmpty) {
          await _storage.write(key: _storageKey, value: content);
        }
        await legacyFile.delete();
      }
    } catch (_) {
      // Migration failure is non-fatal; queue starts empty
    }
  }

  static Future<List<Map<String, dynamic>>> getPending() async {
    await _migrateLegacyIfNeeded();
    try {
      final content = await _storage.read(key: _storageKey);
      if (content == null || content.isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> enqueue({
    required String tipo,
    double? lat,
    double? long,
    String? lugarId,
    required String idempotencyKey,
    required String timestampDispositivo,
  }) async {
    final pending = await getPending();
    pending.add({
      'tipo': tipo,
      'lat': lat,
      'long': long,
      'lugar_id': lugarId,
      'idempotency_key': idempotencyKey,
      'timestamp_dispositivo': timestampDispositivo,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await _savePending(pending);
  }

  static Future<void> _savePending(List<Map<String, dynamic>> pending) async {
    await _storage.write(key: _storageKey, value: jsonEncode(pending));
  }

  static Future<int> get pendingCount async {
    final pending = await getPending();
    return pending.length;
  }

  /// Sync all pending fichajes. Returns count of successfully synced items.
  static Future<({int synced, int failed})> syncAll() async {
    final pending = await getPending();
    if (pending.isEmpty) return (synced: 0, failed: 0);

    if (pending.length == 1) {
      final item = pending.first;
      final result = await FichajesApiService.postFichaje(
        tipo: item['tipo'] as String,
        lat: (item['lat'] as num?)?.toDouble(),
        long: (item['long'] as num?)?.toDouble(),
        lugarId: item['lugar_id'] as String?,
        idempotencyKey: item['idempotency_key'] as String?,
      );
      if (result.fichaje != null) {
        await _savePending([]);
        return (synced: 1, failed: 0);
      }
      return (synced: 0, failed: 1);
    }

    final batchBody = pending
        .map(
          (item) => {
            'tipo': item['tipo'],
            if (item['lat'] != null) 'lat': item['lat'],
            if (item['long'] != null) 'long': item['long'],
            if (item['lugar_id'] != null) 'lugar_id': item['lugar_id'],
            if (item['idempotency_key'] != null)
              'idempotency_key': item['idempotency_key'],
            if (item['timestamp_dispositivo'] != null)
              'timestamp_dispositivo': item['timestamp_dispositivo'],
          },
        )
        .toList();

    try {
      final url = Uri.parse('${ApiClient.baseUrl}/api/v1/fichajes/batch');
      final res = await ApiClient.client
          .post(
            url,
            headers: await ApiClient.authHeaders(),
            body: jsonEncode({'fichajes': batchBody}),
          )
          .timeout(ApiClient.exportTimeout);

      if (res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final inserted = body['inserted'] as List<dynamic>? ?? [];
        final errors = body['errors'] as List<dynamic>? ?? [];

        final successKeys = inserted
            .map(
              (e) => (e as Map<String, dynamic>)['idempotency_key'] as String?,
            )
            .whereType<String>()
            .toSet();

        final remaining = pending
            .where((item) => !successKeys.contains(item['idempotency_key']))
            .toList();

        await _savePending(remaining);
        return (synced: inserted.length, failed: errors.length);
      }
    } catch (_) {
      // Network error during sync; keep queue intact
    }
    return (synced: 0, failed: pending.length);
  }
}
