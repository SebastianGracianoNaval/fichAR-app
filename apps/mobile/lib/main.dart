import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  final url = dotenv.env['SUPABASE_URL'];
  final anonKey = dotenv.env['SUPABASE_ANON_KEY'];
  final apiUrl = dotenv.env['API_URL'];

  if (
      url == null ||
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

  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
  );

  runApp(const FicharApp());
}
