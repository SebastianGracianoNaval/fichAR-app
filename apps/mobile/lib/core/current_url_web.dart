// Web: get full URL including hash (for Supabase auth redirect recovery).
// Uses package:web (replacement for deprecated dart:html).
import 'package:web/web.dart' as web;

/// Returns the current page URL including fragment (#access_token=...).
/// Only used on web for password recovery / OAuth callback.
Uri? getCurrentUrl() {
  final href = web.window.location.href;
  return href.isNotEmpty ? Uri.parse(href) : null;
}

/// Raw href string for debug logs (what the app sees before router).
String? getCurrentUrlRaw() => web.window.location.href;
