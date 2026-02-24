import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

String formatApiError(Object e) {
  final s = e.toString();
  return s.startsWith('Exception: ') ? s.substring(11) : s;
}

/// User-facing friendly message. Hides technical details (AGENTS.md: user-facing generic for security).
String friendlyError(Object e) {
  if (e is TimeoutException) {
    return 'La conexión tardó demasiado. Revisá tu conexión e intentá de nuevo.';
  }
  if (e is SocketException || e is http.ClientException) {
    return 'Sin conexión. Verificá que tengas internet e intentá de nuevo.';
  }
  if (e.toString().contains('TypeError') ||
      (e.toString().contains('type ') &&
          e.toString().contains('is not a subtype'))) {
    return 'Error al cargar los datos. Intentá de nuevo.';
  }
  final s = formatApiError(e);
  if (s.length > 80 || s.contains('Instance of') || s.contains('Exception')) {
    return 'Ocurrió un error inesperado. Intentá de nuevo.';
  }
  return s;
}
