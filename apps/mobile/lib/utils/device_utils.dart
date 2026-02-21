import 'dart:io';

/// Detects if current device is low-end.
/// Low-end: Android API <24, iOS <14, or memory <2GB.
/// Reference: fichar-low-end SKILL, OPTIMIZACION §2.3.
///
/// Requires `device_info_plus` package. When not available, defaults to false.
/// Add to pubspec.yaml: device_info_plus: ^11.0.0
Future<bool> isLowEndDevice() async {
  try {
    if (Platform.isAndroid) {
      // Requires: final androidInfo = await DeviceInfoPlugin().androidInfo;
      // return androidInfo.version.sdkInt < 24;
      return false;
    }
    if (Platform.isIOS) {
      // Requires: final iosInfo = await DeviceInfoPlugin().iosInfo;
      // final major = int.tryParse(iosInfo.systemVersion.split('.').first) ?? 0;
      // return major < 14;
      return false;
    }
  } catch (_) {
    // Fallback: assume not low-end
  }
  return false;
}
