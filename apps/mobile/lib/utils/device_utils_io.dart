// Real device detection for Android/iOS. Web uses device_utils_stub.
// Reference: plan-refactor-compatibility.md, fichar-low-end SKILL,
// definiciones/FRONTEND.md §3

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';

/// Detects if current device is low-end.
/// Low-end: Android API < 24, iOS < 14 (definiciones/FRONTEND.md §3.1).
/// Web/Desktop: assume high-end (returns false).
/// On error: assume high-end (never throw; no romper).
Future<bool> isLowEndDevice() async {
  try {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt < 24;
    }
    if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      final major = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
      return major < 14;
    }
  } catch (_) {
    // Fallback: assume high-end. Never throw.
  }
  return false;
}
