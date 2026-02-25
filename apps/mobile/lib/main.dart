import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/current_url.dart';
import 'core/device_capabilities.dart';
import 'core/invite_from_url.dart';
import 'core/recovery_from_url_flag.dart';

Future<void> main() async {
  // Capture URL with fragment BEFORE any Flutter init; the router/engine may strip # later.
  // Do not call setPathUrlStrategy() or configure routing before this; recovery would break.
  final capturedUrl = kIsWeb ? getCurrentUrl() : null;
  if (kIsWeb && capturedUrl != null && capturedUrl.fragment.isNotEmpty) {
    debugPrint('URL detectada en el arranque: ${capturedUrl.toString()}');
  }
  if (kIsWeb && capturedUrl != null) {
    final q = capturedUrl.queryParameters;
    String? token = q['inviteToken'];
    String? email = q['email'];
    if (token == null && capturedUrl.fragment.isNotEmpty) {
      final frag = capturedUrl.fragment;
      if (frag.contains('inviteToken=')) {
        final params = Uri.splitQueryString(frag.contains('?') ? frag.substring(frag.indexOf('?') + 1) : frag);
        token = params['inviteToken'];
        email = params['email'];
      }
    }
    if (token != null && token.isNotEmpty) {
      setInviteFromUrl(token: token, email: email);
    }
  }

  WidgetsFlutterBinding.ensureInitialized();

  await DeviceCapabilities.init();

  await dotenv.load(fileName: "assets/.env");

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
  final apiUrl = dotenv.env['API_URL'];

  if (url == null ||
      url.isEmpty ||
      anonKey == null ||
      anonKey.isEmpty ||
      apiUrl == null ||
      apiUrl.isEmpty) {
    throw Exception(
      'SUPABASE_URL, SUPABASE_ANON_KEY y API_URL deben estar en apps/mobile/assets/.env. '
      'Copia desde .env en la raiz o desde assets/env.example.',
    );
  }

  // Web: implicit flow so getSessionFromUrl accepts #access_token=... (recovery redirect).
  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
    authOptions: kIsWeb
        ? const FlutterAuthClientOptions(authFlowType: AuthFlowType.implicit)
        : const FlutterAuthClientOptions(),
  );

  // Log what the app sees after init (router may have stripped fragment by then).
  if (kIsWeb) {
    final hrefAfterInit = getCurrentUrlRaw();
    debugPrint(
      'window.location.href (después de Supabase.initialize): $hrefAfterInit',
    );
  }

  // P-AUTH-03 / recovery: use the URL captured at startup; block until session is processed.
  if (kIsWeb &&
      capturedUrl != null &&
      capturedUrl.fragment.isNotEmpty &&
      (capturedUrl.fragment.contains('access_token=') ||
          capturedUrl.fragment.contains('type=recovery'))) {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(capturedUrl);
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        debugPrint('Sesión de recuperación detectada y establecida');
        setRecoveryFromUrl(true);
      }
    } catch (e, st) {
      if (kReleaseMode) {
        debugPrint('getSessionFromUrl failed: $e');
      } else {
        debugPrint('getSessionFromUrl failed: $e\n$st');
      }
    }
  }

  ApiClient.init();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const FicharApp(),
    ),
  );
}
