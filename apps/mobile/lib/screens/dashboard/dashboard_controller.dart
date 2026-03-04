// Dashboard state and async logic (plan Step 11). Used by DashboardScreen.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/device_capabilities.dart';
import '../../core/geolocation_service.dart';
import '../../core/offline_queue.dart';
import '../../core/org_config_provider.dart';
import '../../core/places_cache.dart';
import '../../services/dashboard_api_service.dart';
import '../../services/fichajes_api_service.dart';
import '../../services/licencias_api_service.dart';
import '../../services/me_api_service.dart';
import '../../services/sign_out_service.dart';
import '../../theme.dart';
import '../../utils/error_utils.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    required this.role,
    required this.isMounted,
    this.onFichajeSuccess,
  });

  final String role;
  final bool Function() isMounted;
  /// Called after a successful fichar (plan Step 13, ux-feedback-guide).
  final void Function()? onFichajeSuccess;

  bool fichajeLoading = false;
  String? fichajeError;
  String? nextTipo;
  Fichaje? lastFichaje;
  double? saldoHoras;
  bool dayLoading = true;
  DashboardKpis? kpis;
  bool kpisLoading = true;
  String? kpisError;
  String? orgName;
  String? userName;
  String? userEmail;
  bool profileIncomplete = false;
  bool signingOut = false;
  bool geoChecking = true;
  String? geoMessage;
  String? geoPlaceId;
  double? geoLat;
  double? geoLong;
  bool geoOpenSettings = false;

  bool get isEmployee => ['empleado', 'supervisor', 'admin'].contains(role);

  bool get canFicharByGeo {
    if (!isEmployee) return true;
    if (nextTipo != 'entrada') return true;
    if (!OrgConfigProvider.geolocalizacionObligatoria) return true;
    return !geoChecking && geoMessage == null;
  }

  static String formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  void start() {
    loadMe();
    if (isEmployee) {
      loadDayData();
      resolveGeolocation();
    } else {
      geoChecking = false;
      notifyListeners();
    }
    if (role == 'admin') loadKpis();
  }

  Future<void> resolveGeolocation() async {
    if (!OrgConfigProvider.geolocalizacionObligatoria) {
      if (!isMounted()) return;
      geoChecking = false;
      geoMessage = null;
      notifyListeners();
      return;
    }
    if (!isMounted()) return;
    geoChecking = true;
    notifyListeners();
    List<Place> places = [];
    bool placesLoadFailed = false;
    try {
      places = await PlacesCache.getPlaces();
    } catch (e, st) {
      placesLoadFailed = true;
      debugPrint('PlacesCache.getPlaces failed: $e');
      assert(() {
        debugPrint('$st');
        return true;
      }());
    }
    if (!isMounted()) return;
    final result = await checkCanFichar(
      geolocRequired: true,
      toleranceM: OrgConfigProvider.toleranciaGpsMetros,
      places: places,
    );
    if (!isMounted()) return;
    geoChecking = false;
    geoMessage = result.allowed ? null : result.message;
    if (placesLoadFailed && (geoMessage == null || geoMessage!.isEmpty)) {
      geoMessage = 'No se pudieron cargar los lugares.';
    }
    geoPlaceId = result.placeId;
    geoLat = result.lat;
    geoLong = result.long;
    geoOpenSettings = result.openSettings;
    notifyListeners();
  }

  Future<void> loadMe() async {
    final result = await MeApiService.getMe();
    if (!isMounted()) return;
    orgName = result.result?.orgName;
    userName = result.result?.name?.trim();
    userEmail = result.result?.email;
    profileIncomplete = result.result != null &&
        (result.result!.name == null || result.result!.name!.trim().isEmpty);
    notifyListeners();
  }

  Future<void> loadKpis() async {
    kpisLoading = true;
    kpisError = null;
    notifyListeners();
    final result = await DashboardApiService.getAdminDashboard();
    if (!isMounted()) return;
    kpisLoading = false;
    kpis = result.data;
    kpisError = result.error;
    notifyListeners();
  }

  Future<void> loadDayData() async {
    dayLoading = true;
    notifyListeners();
    final now = DateTime.now();
    final desde = DateTime(now.year, now.month, now.day).toIso8601String();
    final hasta = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final bancoFuture = OrgConfigProvider.bancoHorasHabilitado
        ? LicenciasApiService.getBanco()
        : Future.value((saldoHoras: 0.0, error: null as String?));
    final results = await Future.wait([
      FichajesApiService.getFichajes(desde: desde, hasta: hasta, limit: 10),
      bancoFuture,
    ]);
    if (!isMounted()) return;
    final fichajesResult = results[0] as ({List<Fichaje> data, int total, String? error});
    final bancoResult = results[1] as ({double saldoHoras, String? error});
    String next = 'entrada';
    Fichaje? last;
    if (fichajesResult.data.isNotEmpty) {
      last = fichajesResult.data.first;
      next = last.tipo == 'entrada' ? 'salida' : 'entrada';
    }
    dayLoading = false;
    nextTipo = next;
    lastFichaje = last;
    saldoHoras = bancoResult.saldoHoras;
    notifyListeners();
  }

  Future<void> fichar() async {
    if (fichajeLoading || nextTipo == null || !canFicharByGeo) return;
    fichajeLoading = true;
    fichajeError = null;
    notifyListeners();
    try {
      final result = await FichajesApiService.postFichaje(
        tipo: nextTipo!,
        lat: nextTipo == 'entrada' ? geoLat : null,
        long: nextTipo == 'entrada' ? geoLong : null,
        lugarId: nextTipo == 'entrada' ? geoPlaceId : null,
      );
      if (!isMounted()) return;
      if (result.fichaje != null) {
        HapticFeedback.mediumImpact();
        lastFichaje = result.fichaje;
        nextTipo = result.fichaje!.tipo == 'entrada' ? 'salida' : 'entrada';
        fichajeLoading = false;
        notifyListeners();
        onFichajeSuccess?.call();
      } else {
        if (DeviceCapabilities.hasHaptics) HapticFeedback.heavyImpact();
        fichajeError = result.error;
        fichajeLoading = false;
        notifyListeners();
      }
    } on SocketException {
      await _handleNetworkFichajeError();
    } on TimeoutException {
      await _handleNetworkFichajeError();
    } on http.ClientException {
      await _handleNetworkFichajeError();
    } catch (e) {
      if (!isMounted()) return;
      if (DeviceCapabilities.hasHaptics) HapticFeedback.heavyImpact();
      fichajeError = formatApiError(e);
      fichajeLoading = false;
      notifyListeners();
    }
  }

  /// On network error: enqueue if CFG-009 allows, else show message (plan T2, F27).
  Future<void> _handleNetworkFichajeError() async {
    if (!isMounted()) return;
    if (!OrgConfigProvider.modoOfflineHabilitado) {
      if (DeviceCapabilities.hasHaptics) HapticFeedback.heavyImpact();
      fichajeError = 'Sin conexion. El modo offline esta deshabilitado por tu organizacion.';
      fichajeLoading = false;
      notifyListeners();
      return;
    }
    await queueOffline();
  }

  Future<void> queueOffline() async {
    final key = '${DateTime.now().millisecondsSinceEpoch}-$nextTipo';
    await OfflineQueue.enqueue(
      tipo: nextTipo!,
      idempotencyKey: key,
      timestampDispositivo: DateTime.now().toIso8601String(),
    );
    if (!isMounted()) return;
    HapticFeedback.lightImpact();
    fichajeError = 'Sin conexion. Fichaje guardado para enviar cuando vuelvas a tener red.';
    fichajeLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (signingOut) return;
    signingOut = true;
    notifyListeners();
    OrgConfigProvider.clear();
    clearFicharThemeCache();
    final result = await SignOutService.signOutDetailed();
    if (!isMounted()) return;
    signingOut = false;
    notifyListeners();
    // Caller must show SnackBar and navigate using the BuildContext.
    _signOutResult = result;
  }

  ({bool signedOut, bool wasLocal})? _signOutResult;
  ({bool signedOut, bool wasLocal})? takeSignOutResult() {
    final r = _signOutResult;
    _signOutResult = null;
    return r;
  }
}
