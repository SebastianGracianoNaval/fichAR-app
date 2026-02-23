// Stub for web platform. dart:io and device_info_plus androidInfo/iosInfo
// are not available on web. Assume high-end (better UX).
// Reference: plan-refactor-compatibility.md, definiciones/FRONTEND.md §3

/// Returns false on web (high-end). Real detection in device_utils_io.dart.
Future<bool> isLowEndDevice() async => false;
