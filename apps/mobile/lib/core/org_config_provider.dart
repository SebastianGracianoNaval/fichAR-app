// In-memory cache for org configs (CFG-*). Load after login/session restore.
// Reference: definiciones/CONFIGURACIONES.md, plan Step 7.

import 'dart:convert';

import '../services/org_configs_api_service.dart';

class OrgConfigProvider {
  OrgConfigProvider._();

  static List<OrgConfigItem> _cache = [];
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Fetch configs from API and cache. Call after session is established (e.g. after getMe).
  static Future<void> load() async {
    final result = await OrgConfigsApiService.getConfigs();
    if (result.error != null) {
      _cache = [];
      _loaded = true;
      return;
    }
    _cache = result.data;
    _loaded = true;
  }

  /// Clear cache (e.g. on sign out). Next access will use defaults until load() is called again.
  static void clear() {
    _cache = [];
    _loaded = false;
  }

  static OrgConfigItem? _find(String key) {
    for (final e in _cache) {
      if (e.key == key) return e;
    }
    return null;
  }

  static bool _getBool(String key, bool defaultValue) {
    final item = _find(key);
    if (item == null) return defaultValue;
    if (item.value is bool) return item.value as bool;
    if (item.value == true || item.value == 'true') return true;
    if (item.value == false || item.value == 'false') return false;
    return defaultValue;
  }

  static String _getString(String key, String defaultValue) {
    final item = _find(key);
    if (item == null) return defaultValue;
    if (item.value is String) return item.value as String;
    return defaultValue;
  }

  static int _getNumber(String key, int defaultValue) {
    final item = _find(key);
    if (item == null) return defaultValue;
    if (item.value is int) return item.value as int;
    if (item.value is num) return (item.value as num).toInt();
    if (item.value is String) {
      final n = int.tryParse((item.value as String).trim());
      return n ?? defaultValue;
    }
    return defaultValue;
  }

  // --- CFG keys used by the app (CONFIGURACIONES.md) ---

  static bool get appMobileHabilitada => _getBool('app_mobile_habilitada', true);
  static bool get appWebHabilitada => _getBool('app_web_habilitada', true);
  static bool get appDesktopHabilitada => _getBool('app_desktop_habilitada', true);

  static bool get geolocalizacionObligatoria => _getBool('geolocalizacion_obligatoria', true);
  /// CFG-007: tolerancia en metros (radio + tolerancia = zona válida). Default 10.
  static int get toleranciaGpsMetros => _getNumber('tolerancia_gps_metros', 10);
  static bool get modoOfflineHabilitado => _getBool('modo_offline_habilitado', true);

  static bool get bancoHorasHabilitado => _getBool('banco_horas_habilitado', true);
  static bool get tareasHabilitado => _getBool('tareas_habilitado', false);
  static bool get biometriaHabilitada => _getBool('biometria_habilitada', true);

  static bool get licenciasAdjuntoObligatorio => _getBool('licencias_adjunto_obligatorio', true);

  /// CFG-039: siempre | una_vez_dia | una_vez_semana | nunca
  static String get sabiasQueFrecuencia => _getString('sabias_que_frecuencia', 'una_vez_dia');

  /// CFG-042: profesional | fresco | neutro | custom
  static String get orgColorPalette => _getString('org_color_palette', 'profesional');
  static String get orgColorPrimary => _getString('org_color_primary', '');
  static String get orgColorSecondary => _getString('org_color_secondary', '');

  static const List<String> _defaultLicenciasTipos = [
    'enfermedad', 'accidente', 'matrimonio', 'maternidad',
    'paternidad', 'duelo', 'estudio', 'otro',
  ];

  /// CFG-018: JSON array of allowed license types.
  static List<String> get licenciasTiposPermitidos {
    final raw = _getString(
      'licencias_tipos_permitidos',
      '["enfermedad","accidente","matrimonio","maternidad","paternidad","duelo","estudio","otro"]',
    );
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! List) return _defaultLicenciasTipos;
      final list = decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      return list.isEmpty ? _defaultLicenciasTipos : list;
    } catch (_) {
      return _defaultLicenciasTipos;
    }
  }
}
