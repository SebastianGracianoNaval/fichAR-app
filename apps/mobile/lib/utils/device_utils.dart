// Platform-conditional export. Web uses stub; mobile/desktop use real detection.
// Reference: plan-refactor-compatibility.md

export 'device_utils_stub.dart'
    if (dart.library.io) 'device_utils_io.dart';
