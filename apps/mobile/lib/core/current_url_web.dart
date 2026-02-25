// Web: get full URL including hash (for Supabase auth redirect recovery).
// Uses dart:html to avoid ES module output that causes "Unexpected token export" in Flutter web.
import 'dart:html' as html;

/// Returns the current page URL including fragment (#access_token=...).
/// Only used on web for password recovery / OAuth callback.
Uri? getCurrentUrl() {
  final href = html.window.location.href;
  return href.isNotEmpty ? Uri.parse(href) : null;
}

/// Raw href string for debug logs (what the app sees before router).
String? getCurrentUrlRaw() => html.window.location.href;
