// Device capability flags for graceful degradation (plan-refactor-compatibility).
// Reference: definiciones/FRONTEND.md §3, fichar-low-end SKILL.

import '../utils/device_utils.dart';

/// Capability flags for low-end vs high-end. Call [init] before runApp.
class DeviceCapabilities {
  DeviceCapabilities._();

  static bool _initialized = false;
  static bool _isLowEnd = false;
  static bool _hasHaptics = true;
  static bool _hasAnimations = true;
  static bool _canPlaySounds = true;

  static bool get isLowEnd => _isLowEnd;
  static bool get hasHaptics => _hasHaptics;
  static bool get hasAnimations => _hasAnimations;
  static bool get canPlaySounds => _canPlaySounds;

  /// Initialize capability flags. Call in main() before runApp().
  static Future<void> init() async {
    if (_initialized) return;
    _isLowEnd = await isLowEndDevice();
    _hasHaptics = !_isLowEnd;
    _hasAnimations = !_isLowEnd;
    _canPlaySounds = !_isLowEnd;
    _initialized = true;
  }
}
