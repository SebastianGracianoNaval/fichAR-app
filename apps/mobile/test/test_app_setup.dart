// Test setup: load env, init Supabase and ApiClient for widget tests.
// Screens with API on init (Licencias, Perfil, Admin*) need this before pumpWidget.
// Idempotent: safe to call from multiple test files.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fichar_mobile/core/api_client.dart';

bool _testAppEnvInitialized = false;

String _testSessionString() {
  final exp =
      (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000);
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({'exp': exp, 'sub': 'test', 'role': 'authenticated'}),
    ),
  );
  final accessToken = 'header.$payload.sig';
  return '{"access_token":"$accessToken","expires_in":3600,"refresh_token":"test-refresh","token_type":"bearer","user":{"id":"test-user-id","email":"test@test.com"}}';
}

class _TestLocalStorage extends LocalStorage {
  _TestLocalStorage() : super();

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async => _testSessionString();

  @override
  Future<bool> hasAccessToken() async => true;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}

class _TestAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _map = {};

  @override
  Future<String?> getItem({required String key}) async => _map[key];

  @override
  Future<void> removeItem({required String key}) async => _map.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _map[key] = value;
}

Future<void> initTestAppEnv() async {
  if (_testAppEnvInitialized) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  final candidates = ['test/env.test', 'apps/mobile/test/env.test'];
  File? envFile;
  for (final p in candidates) {
    final f = File(p);
    if (f.existsSync()) {
      envFile = f;
      break;
    }
  }
  if (envFile != null) {
    dotenv.loadFromString(envString: envFile.readAsStringSync());
  } else {
    dotenv.loadFromString(
      envString: '''
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test-anon-key-for-widget-tests
API_URL=http://localhost:9999
''',
    );
  }
  SharedPreferences.setMockInitialValues(<String, Object>{});
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: FlutterAuthClientOptions(
        localStorage: _TestLocalStorage(),
        pkceAsyncStorage: _TestAsyncStorage(),
      ),
    );
  } catch (_) {
    // Already initialized (e.g. from another test file).
  }
  ApiClient.init();
  _testAppEnvInitialized = true;
}
