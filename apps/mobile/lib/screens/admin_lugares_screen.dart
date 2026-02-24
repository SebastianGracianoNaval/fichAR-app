import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/device_capabilities.dart';
import '../services/places_api_service.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

const _diasOptions = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

class AdminLugaresScreen extends StatefulWidget {
  const AdminLugaresScreen({super.key});

  @override
  State<AdminLugaresScreen> createState() => _AdminLugaresScreenState();
}

class _AdminLugaresScreenState extends State<AdminLugaresScreen> {
  List<AdminPlace> _places = [];
  bool _loading = true;
  String? _error;
  int _total = 0;
  int _offset = 0;
  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
    });
    try {
      final result = await PlacesApiService.getPlaces(limit: _limit, offset: 0);
      if (!mounted) return;
      setState(() {
        _places = result.data;
        _total = result.total;
        _offset = result.offset + result.data.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = formatApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _places.length >= _total) return;
    setState(() => _loading = true);
    try {
      final result = await PlacesApiService.getPlaces(
        limit: _limit,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _places = [..._places, ...result.data];
        _offset = result.offset + result.data.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = formatApiError(e);
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo leer el archivo')),
        );
      }
      return;
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final r = await PlacesApiService.importPlaces(bytes, file.name);
      if (!mounted) return;
      navigator.pop();
      final msg = r.errors.isEmpty
          ? 'Importados: ${r.imported}'
          : 'Importados: ${r.imported}. Errores: ${r.errors.length}';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      _load();
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(formatApiError(e))));
    }
  }

  void _openForm({AdminPlace? place}) {
    if (DeviceCapabilities.hasHaptics) {
      HapticFeedback.lightImpact();
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => PlaceFormDialog(
        place: place,
        onSaved: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                place == null ? 'Lugar creado' : 'Lugar actualizado',
              ),
            ),
          );
          _load();
        },
      ),
    );
  }

  Future<void> _delete(AdminPlace place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar lugar'),
        content: Text('Eliminar "${place.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await PlacesApiService.deletePlace(place.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lugar eliminado')));
      _load();
    } catch (e) {
      if (!mounted) return;
      if (DeviceCapabilities.hasHaptics) {
        HapticFeedback.heavyImpact();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatApiError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lugares de trabajo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _import,
            tooltip: 'Importar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ResponsiveContentWrapper(
          width: ContentWidth.list,
          child: _buildBody(theme),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo lugar'),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading && _places.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(kSpacingMd),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_error != null && _places.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(kSpacingMd),
        children: [
          InlineError(message: _error!, onRetry: _load, isLoading: false),
        ],
      );
    }
    if (_places.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(kSpacingMd),
        children: [
          const SizedBox(height: kSpacingXl),
          Icon(
            Icons.location_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: kSpacingMd),
          Text(
            'No hay lugares. Creá uno para que los empleados puedan fichar con geolocalización.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        kSpacingMd,
        kSpacingMd,
        kSpacingMd,
        100,
      ),
      itemCount: _places.length + (_places.length < _total ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _places.length) {
          _loadMore();
          return const Padding(
            padding: EdgeInsets.all(kSpacingMd),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final place = _places[index];
        return _PlaceCard(
          place: place,
          onTap: () => _openForm(place: place),
          onDelete: () => _delete(place),
        );
      },
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.onTap,
    required this.onDelete,
  });

  final AdminPlace place;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: kSpacingMd),
      elevation: DeviceCapabilities.isLowEnd ? 0 : 1,
      shadowColor: DeviceCapabilities.isLowEnd
          ? null
          : Colors.black.withValues(alpha: 0.06),
      child: ListTile(
        title: Text(place.nombre),
        subtitle: Text(place.direccion),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${place.radioM}m', style: theme.textTheme.bodySmall),
            const SizedBox(width: kSpacingSm),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class PlaceFormDialog extends StatefulWidget {
  const PlaceFormDialog({super.key, this.place, required this.onSaved});

  final AdminPlace? place;
  final VoidCallback onSaved;

  @override
  State<PlaceFormDialog> createState() => _PlaceFormDialogState();
}

class _PlaceFormDialogState extends State<PlaceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _direccionController;
  late TextEditingController _latController;
  late TextEditingController _longController;
  late TextEditingController _radioController;
  late Set<String> _dias;
  bool _saving = false;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _direccionController = TextEditingController(text: p?.direccion ?? '');
    _latController = TextEditingController(text: p?.lat.toString() ?? '');
    _longController = TextEditingController(text: p?.long.toString() ?? '');
    _radioController = TextEditingController(
      text: p?.radioM.toString() ?? '100',
    );
    _dias = Set.from(p?.dias ?? ['L', 'M', 'X', 'J', 'V']);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _latController.dispose();
    _longController.dispose();
    _radioController.dispose();
    super.dispose();
  }

  String? _validateNombre(String? v) {
    if (v == null || v.trim().isEmpty) return 'Nombre requerido';
    if (v.length > 200) return 'Max 200 caracteres';
    return null;
  }

  String? _validateDireccion(String? v) {
    if (v == null || v.trim().isEmpty) return 'Dirección requerida';
    return null;
  }

  String? _validateCoord(String? v, String label, double min, double max) {
    if (v == null || v.trim().isEmpty) return '$label requerido';
    final n = double.tryParse(v.trim());
    if (n == null) return '$label inválido';
    if (n < min || n > max) {
      return 'Coordenadas inválidas. Lat[-90,90], Long[-180,180].';
    }
    return null;
  }

  String? _validateRadio(String? v) {
    if (v == null || v.trim().isEmpty) return 'Radio requerido (50-500)';
    final n = int.tryParse(v.trim());
    if (n == null || n < 50 || n > 500) {
      return 'Radio debe estar entre 50 y 500 metros.';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() => _fieldError = null);
    if (!_formKey.currentState!.validate()) return;
    if (_dias.isEmpty) {
      setState(() => _fieldError = 'Seleccioná al menos un día');
      return;
    }

    setState(() => _saving = true);
    try {
      final nombre = _nombreController.text.trim();
      final direccion = _direccionController.text.trim();
      final lat = double.parse(_latController.text.trim());
      final long = double.parse(_longController.text.trim());
      final radio = int.parse(_radioController.text.trim());
      final dias = _dias.toList()..sort();

      if (widget.place != null) {
        await PlacesApiService.updatePlace(
          widget.place!.id,
          nombre: nombre,
          direccion: direccion,
          lat: lat,
          long: long,
          radioM: radio,
          dias: dias,
        );
      } else {
        await PlacesApiService.createPlace(
          nombre: nombre,
          direccion: direccion,
          lat: lat,
          long: long,
          radioM: radio,
          dias: dias,
        );
      }
      if (!mounted) return;
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      if (DeviceCapabilities.hasHaptics) {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _saving = false;
        _fieldError = formatApiError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.place == null ? 'Nuevo lugar' : 'Editar lugar'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                maxLength: 200,
                validator: _validateNombre,
              ),
              const SizedBox(height: kSpacingMd),
              TextFormField(
                controller: _direccionController,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: _validateDireccion,
              ),
              const SizedBox(height: kSpacingMd),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: 'Lat'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => _validateCoord(v, 'Lat', -90, 90),
                    ),
                  ),
                  const SizedBox(width: kSpacingSm),
                  Expanded(
                    child: TextFormField(
                      controller: _longController,
                      decoration: const InputDecoration(labelText: 'Long'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => _validateCoord(v, 'Long', -180, 180),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpacingMd),
              TextFormField(
                controller: _radioController,
                decoration: const InputDecoration(labelText: 'Radio (m)'),
                keyboardType: TextInputType.number,
                validator: _validateRadio,
              ),
              const SizedBox(height: kSpacingMd),
              Text('Días', style: theme.textTheme.labelLarge),
              const SizedBox(height: kSpacingXs),
              Wrap(
                spacing: kSpacingSm,
                runSpacing: kSpacingXs,
                children: _diasOptions.map((d) {
                  final selected = _dias.contains(d);
                  return FilterChip(
                    label: Text(d),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _dias.add(d);
                        } else {
                          _dias.remove(d);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              if (_fieldError != null) ...[
                const SizedBox(height: kSpacingMd),
                Text(
                  _fieldError!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () {
                  if (DeviceCapabilities.hasHaptics) {
                    HapticFeedback.lightImpact();
                  }
                  _save();
                },
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
