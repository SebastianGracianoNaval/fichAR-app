import 'dart:async';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized HTTP client. Base URL, token, auth headers, timeouts, retry.
/// Reference: OPTIMIZACION-RECURSOS-RED §3.5, §3.6
class ApiClient {
  static late final http.Client _client;
  static String? _baseUrl;

  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration exportTimeout = Duration(seconds: 60);

  static void init() {
    _client = http.Client();
    _baseUrl = dotenv.env['API_URL']?.trim();
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw Exception('API_URL no configurado en assets/.env');
    }
  }

  static String get baseUrl =>
      _baseUrl ?? (throw Exception('ApiClient no inicializado'));

  static http.Client get client => _client;

  static Future<String?> getToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null) throw Exception('No hay sesión activa');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Retry with exponential backoff for network errors only.
  /// OPTIMIZACION-RECURSOS-RED §3.5: 1s, 2s, 4s; max 4 attempts.
  static Future<T> withRetry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 4,
    List<Duration> delays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await fn();
      } catch (e) {
        attempt++;
        if (attempt >= maxAttempts) rethrow;
        final isNetworkError =
            e is SocketException ||
            e is TimeoutException ||
            e is http.ClientException;
        if (!isNetworkError) rethrow;
        final delayIdx = (attempt - 1).clamp(0, delays.length - 1);
        await Future.delayed(delays[delayIdx]);
      }
    }
  }

  static void dispose() => _client.close();
}
