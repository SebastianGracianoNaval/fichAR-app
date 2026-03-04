import 'package:flutter_test/flutter_test.dart';
import 'package:fichar_mobile/core/device_capabilities.dart';

void main() {
  test('DeviceCapabilities init sets capability flags', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await DeviceCapabilities.init();

    expect(DeviceCapabilities.isLowEnd, isA<bool>());
    expect(DeviceCapabilities.hasHaptics, isA<bool>());
    expect(DeviceCapabilities.hasAnimations, isA<bool>());
    expect(DeviceCapabilities.canPlaySounds, isA<bool>());
  });
}
