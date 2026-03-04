// Geolocation gating for fichar (CL-001 to CL-005, CFG-005, CFG-007).
// Reference: definiciones/CASOS-LIMITE.md, CONFIGURACIONES.md, plan Step 6.

import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../services/fichajes_api_service.dart';

/// Result of checking if the user can fichar from current location.
class GeolocationResult {
  const GeolocationResult({
    required this.allowed,
    this.message,
    this.placeId,
    this.lat,
    this.long,
    this.openSettings = false,
  });

  final bool allowed;
  final String? message;
  final String? placeId;
  final double? lat;
  final double? long;
  final bool openSettings;
}

/// CL-001 message (fuera de zona).
const String kMsgFueraZona =
    'Estás fuera de tu zona de trabajo. Acercate a tu lugar asignado para fichar.';

/// CL-003 message (GPS deshabilitado).
const String kMsgGpsDeshabilitado = 'Activa la ubicación para poder fichar.';

/// CL-004 message (impreciso, timeout).
const String kMsgGpsImpreciso =
    'No pudimos obtener tu ubicación con precisión. Intentá acercarte a una ventana o salir.';

/// CL-004 message while waiting.
const String kMsgMejorandoPrecision =
    'Esperá un momento, mejorando la precisión de tu ubicación...';

/// Min accuracy in meters to allow fichar (CL-004).
const double kAccuracyThresholdM = 50;

/// Max time waiting for accuracy (CL-004).
const Duration kAccuracyTimeout = Duration(seconds: 30);

/// Retry interval while waiting for accuracy (CL-004).
const Duration kAccuracyRetryInterval = Duration(seconds: 2);

double _haversineM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000; // Earth radius in meters
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Checks if the user can fichar from current location (entrada only).
/// When [geolocRequired] is false, returns allowed without location.
/// Otherwise checks service (CL-003), accuracy (CL-004), zone (CL-001/CL-005).
/// [toleranceM] from CFG-007; [places] must have lat, long, radio_m.
Future<GeolocationResult> checkCanFichar({
  required bool geolocRequired,
  required int toleranceM,
  required List<Place> places,
}) async {
  if (!geolocRequired) {
    return const GeolocationResult(allowed: true);
  }

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return const GeolocationResult(
      allowed: false,
      message: kMsgGpsDeshabilitado,
      openSettings: true,
    );
  }

  LocationPermission perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    return const GeolocationResult(
      allowed: false,
      message: kMsgGpsDeshabilitado,
      openSettings: true,
    );
  }

  Position position;
  try {
    position = await _getPositionWithAccuracy();
  } on TimeoutException {
    return const GeolocationResult(
      allowed: false,
      message: kMsgGpsImpreciso,
    );
  } on LocationServiceDisabledException {
    return const GeolocationResult(
      allowed: false,
      message: kMsgGpsDeshabilitado,
      openSettings: true,
    );
  } catch (_) {
    return const GeolocationResult(
      allowed: false,
      message: kMsgGpsImpreciso,
    );
  }

  final validPlaces = places.where((p) =>
      p.lat != null && p.long != null && p.radioM != null && p.radioM! > 0).toList();
  if (validPlaces.isEmpty) {
    return const GeolocationResult(
      allowed: false,
      message: kMsgFueraZona,
    );
  }

  final lat = position.latitude;
  final long = position.longitude;
  for (final place in validPlaces) {
    final dist = _haversineM(lat, long, place.lat!, place.long!);
    final limit = (place.radioM ?? 100) + toleranceM;
    if (dist <= limit) {
      return GeolocationResult(
        allowed: true,
        placeId: place.id,
        lat: lat,
        long: long,
      );
    }
  }

  return const GeolocationResult(
    allowed: false,
    message: kMsgFueraZona,
  );
}

/// Gets current position, retrying until accuracy <= 50m or timeout (CL-004).
Future<Position> _getPositionWithAccuracy() async {
  final deadline = DateTime.now().add(kAccuracyTimeout);
  while (DateTime.now().isBefore(deadline)) {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    final acc = position.accuracy;
    if (acc <= kAccuracyThresholdM) return position;
    await Future.delayed(kAccuracyRetryInterval);
  }
  throw TimeoutException('Accuracy not reached within ${kAccuracyTimeout.inSeconds}s');
}

/// Opens system location settings (CL-003 "Configurar").
Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
