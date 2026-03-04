// Stub for SocketException on web (plan T5, F43). dart:io is not available on web.

/// Placeholder so api_client.dart can use [io.SocketException] without importing dart:io on web.
/// On web, real network errors may be other types; retry logic still applies to TimeoutException and ClientException.
class SocketException implements Exception {
  SocketException([String? message]);
}
