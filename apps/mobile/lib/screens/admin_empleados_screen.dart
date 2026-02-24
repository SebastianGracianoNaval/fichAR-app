import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../services/employees_api_service.dart';
import '../services/places_api_service.dart';
import '../utils/error_utils.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

class AdminEmpleadosScreen extends StatefulWidget {
  const AdminEmpleadosScreen({super.key});

  @override
  State<AdminEmpleadosScreen> createState() => _AdminEmpleadosScreenState();
}

class _AdminEmpleadosScreenState extends State<AdminEmpleadosScreen> {
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await EmployeesApiService.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = result.data;
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final r = await EmployeesApiService.importEmployees(bytes, file.name);
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

  Future<void> _offboard(Employee emp) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (!mounted) return;
    final fecha =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja'),
        content: Text('Dar de baja a ${emp.name}? Fecha egreso: $fecha'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await EmployeesApiService.offboardEmployee(emp.id, fecha);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Empleado dado de baja')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(formatApiError(e))));
    }
  }

  Future<void> _editPlaces(Employee emp) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EmployeePlacesDialog(
        employee: emp,
        onSaved: () {
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empleados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _loading ? null : _import,
            tooltip: 'Importar Excel/CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
          : _employees.isEmpty
          ? ResponsiveContentWrapper(
              width: ContentWidth.list,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: kSpacingMd),
                    Text(
                      'No hay empleados',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          : ResponsiveContentWrapper(
              width: ContentWidth.list,
              child: ListView.builder(
                itemCount: _employees.length,
                itemBuilder: (_, i) {
                  final e = _employees[i];
                  return ListTile(
                    title: Text(e.name),
                    subtitle: Text('${e.email} - ${e.role}'),
                    trailing: e.status == 'activo'
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'places') {
                                _editPlaces(e);
                              } else if (v == 'offboard') {
                                _offboard(e);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'places',
                                child: Text('Editar lugares'),
                              ),
                              const PopupMenuItem(
                                value: 'offboard',
                                child: Text('Dar de baja'),
                              ),
                            ],
                          )
                        : Chip(label: Text(e.status)),
                  );
                },
              ),
            ),
    );
  }
}

class _EmployeePlacesDialog extends StatefulWidget {
  const _EmployeePlacesDialog({required this.employee, required this.onSaved});

  final Employee employee;
  final VoidCallback onSaved;

  @override
  State<_EmployeePlacesDialog> createState() => _EmployeePlacesDialogState();
}

class _EmployeePlacesDialogState extends State<_EmployeePlacesDialog> {
  List<AdminPlace> _places = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final emp = await EmployeesApiService.getEmployee(widget.employee.id);
      final placesResult = await PlacesApiService.getPlaces(
        limit: 200,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _places = placesResult.data;
        _selectedIds = Set.from(emp.placeIds ?? []);
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await EmployeesApiService.patchEmployee(
        widget.employee.id,
        placeIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lugares actualizados')));
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formatApiError(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Lugares de ${widget.employee.name}'),
      content: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            )
          : SizedBox(
              width: double.maxFinite,
              child: _places.isEmpty
                  ? const Text(
                      'No hay lugares. Creá lugares desde Admin > Lugares.',
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _places.map((p) {
                        final selected = _selectedIds.contains(p.id);
                        return FilterChip(
                          label: Text(p.nombre),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_loading || _error != null || _saving) ? null : _save,
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
