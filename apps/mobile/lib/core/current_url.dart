// Platform-conditional: web gets full URL (including hash); mobile/desktop returns null.
// Used to recover Supabase session from password recovery redirect on Flutter Web.

export 'current_url_stub.dart' if (dart.library.html) 'current_url_web.dart';
