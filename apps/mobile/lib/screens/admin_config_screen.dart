import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../services/org_configs_api_service.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

const _labels = {
  'geolocalizacion_obligatoria': 'Geolocalizacion obligatoria para fichar',
  'tolerancia_gps_metros': 'Tolerancia GPS (metros)',
  'geolocalizacion_radio_default': 'Radio default de zona (metros)',
  'descanso_minimo_horas': 'Descanso minimo entre jornadas (horas)',
  'mfa_obligatorio_admin': '2FA obligatorio para Admin',
  'modo_offline_habilitado': 'Permitir fichaje offline',
  'import_welcome': 'Enviar email de bienvenida al importar',
  'logs_retencion_dias': 'Retencion de logs (dias)',
  'licencias_aprobador': 'Quien aprueba licencias',
  'dispositivos_maximos': 'Maximo de dispositivos por empleado',
};

const _sections = {
  'Fichaje': [
    'geolocalizacion_obligatoria',
    'tolerancia_gps_metros',
    'geolocalizacion_radio_default',
    'descanso_minimo_horas',
    'modo_offline_habilitado',
  ],
  'Licencias': ['licencias_aprobador'],
  'Seguridad': ['mfa_obligatorio_admin', 'dispositivos_maximos'],
  'Importacion': ['import_welcome'],
  'Logs': ['logs_retencion_dias'],
};

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  List<OrgConfigItem> _configs = [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  final Map<String, dynamic> _draft = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await OrgConfigsApiService.getConfigs();
    if (!mounted) return;
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _draft.clear();
    for (final c in result.data) {
      _draft[c.key] = c.value;
      if (c.type == 'number' && (c.options == null || c.options!.isEmpty)) {
        _controllers[c.key] = TextEditingController(
          text: (c.value as num?)?.toString() ?? '',
        );
      }
    }
    setState(() {
      _loading = false;
      _configs = result.data;
      _error = result.error;
    });
  }

  dynamic _getValue(String key) {
    return _draft[key] ??
        _configs
            .firstWhere(
              (c) => c.key == key,
              orElse: () =>
                  OrgConfigItem(key: key, value: null, type: 'string'),
            )
            .value;
  }

  void _setValue(String key, dynamic value) {
    setState(() => _draft[key] = value);
  }

  Map<String, dynamic> _getChangedConfigs() {
    final changed = <String, dynamic>{};
    for (final c in _configs) {
      dynamic draftVal = _draft[c.key];
      if (c.type == 'number' && (c.options == null || c.options!.isEmpty)) {
        final controller = _controllers[c.key];
        if (controller != null && controller.text.isNotEmpty) {
          final n = int.tryParse(controller.text);
          if (n != null) draftVal = n;
        }
      }
      if (draftVal != null && draftVal != c.value) {
        changed[c.key] = draftVal;
      }
    }
    return changed;
  }

  Future<void> _save() async {
    final changed = _getChangedConfigs();
    if (changed.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin cambios')));
      }
      return;
    }

    if (_saving) return;
    setState(() => _saving = true);

    final result = await OrgConfigsApiService.patchConfigs(changed);
    if (!mounted) return;

    setState(() => _saving = false);

    if (result.ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configuracion guardada')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        actions: [
          if (!_loading && _configs.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ResponsiveContentWrapper(
              width: ContentWidth.list,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                child: InlineError(
                  message: _error!,
                  onRetry: _load,
                  isLoading: false,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ResponsiveContentWrapper(
                width: ContentWidth.list,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sections.length,
                  itemBuilder: (context, idx) {
                    final entry = _sections.entries.elementAt(idx);
                    return _buildSection(theme, entry.key, entry.value);
                  },
                ),
              ),
            ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<String> keys) {
    final items = keys.where((k) => _configs.any((c) => c.key == k)).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: items.map((key) => _buildConfigRow(theme, key)).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildConfigRow(ThemeData theme, String key) {
    final config = _configs.firstWhere(
      (c) => c.key == key,
      orElse: () => OrgConfigItem(key: key, value: null, type: 'string'),
    );
    final label = _labels[key] ?? key;
    final isBool = config.type == 'boolean';
    final value = _getValue(key);

    if (isBool) {
      return SwitchListTile(
        title: Text(label),
        subtitle: _getSubtitle(key),
        value: value == true,
        onChanged: (v) => _setValue(key, v),
      );
    }

    if (config.type == 'select' &&
        config.options != null &&
        config.options!.isNotEmpty) {
      final options = config.options!.map((o) => o as String).toList();
      final current =
          value as String? ?? config.value as String? ?? options.first;
      return ListTile(
        title: Text(label),
        subtitle: _getSubtitle(key),
        trailing: SizedBox(
          width: 140,
          child: DropdownButtonFormField<String>(
            initialValue: options.contains(current) ? current : options.first,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: InputBorder.none,
            ),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => _setValue(key, v),
          ),
        ),
      );
    }

    if (config.type == 'number' &&
        config.options != null &&
        config.options!.isNotEmpty) {
      final options = config.options!
          .map((o) => o as num)
          .map((n) => n.toInt())
          .toList();
      final current = value is num
          ? value.toInt()
          : (config.value is num ? (config.value as num).toInt() : 3);
      return ListTile(
        title: Text(label),
        subtitle: _getSubtitle(key),
        trailing: SizedBox(
          width: 140,
          child: DropdownButtonFormField<int>(
            initialValue: options.contains(current) ? current : options.first,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: InputBorder.none,
            ),
            items: options
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v == -1 ? 'Ilimitado' : v.toString()),
                  ),
                )
                .toList(),
            onChanged: (v) => _setValue(key, v),
          ),
        ),
      );
    }

    final controller = _controllers[key];
    return ListTile(
      title: Text(label),
      subtitle: _getSubtitle(key),
      trailing: SizedBox(
        width: 80,
        child: controller != null
            ? TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                onChanged: (s) {
                  final n = int.tryParse(s);
                  if (n != null) _setValue(key, n);
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget? _getSubtitle(String key) {
    if (key == 'descanso_minimo_horas') {
      return const Text('10, 11 o 12 (Art. 198 LCT)');
    }
    if (key == 'tolerancia_gps_metros') {
      return const Text('0-50');
    }
    if (key == 'geolocalizacion_radio_default') {
      return const Text('50-500');
    }
    if (key == 'logs_retencion_dias') {
      return const Text('365-3650');
    }
    if (key == 'licencias_aprobador') {
      return const Text('supervisor, admin o ambos');
    }
    if (key == 'dispositivos_maximos') {
      return const Text('1, 2, 3, 5, 10 o Ilimitado');
    }
    return null;
  }
}
