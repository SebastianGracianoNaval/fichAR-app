import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../services/auth_api_service.dart';
import '../services/employees_api_service.dart';
import '../services/places_api_service.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive_content_wrapper.dart';
import '../widgets/screen_error_view.dart';

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

  Future<void> _openAddEmployeeDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddEmployeeDialog(
        onInvited: () {
          _load();
        },
      ),
    );
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
            icon: const Icon(Icons.person_add),
            onPressed: _loading ? null : _openAddEmployeeDialog,
            tooltip: 'Agregar empleado',
          ),
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
          ? Center(
              child: ScreenErrorView(
                message: 'Error al listar empleados.',
                subtitle: 'Revisá tu conexión e intentá de nuevo.',
                onAction: _load,
                contentWidth: ContentWidth.list,
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
                      'Bienvenido, agrega a tus empleados',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpacingSm),
                    Text(
                      'Invitalos por email o cargá un archivo Excel/CSV.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpacingLg),
                    FilledButton.icon(
                      onPressed: _loading ? null : _openAddEmployeeDialog,
                      icon: const Icon(Icons.person_add, size: 20),
                      label: const Text('Invitar empleado'),
                    ),
                    const SizedBox(height: kSpacingSm),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _import,
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Cargar desde Excel'),
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

class _AddEmployeeDialog extends StatefulWidget {
  const _AddEmployeeDialog({required this.onInvited});

  final VoidCallback onInvited;

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _dniCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _error = null;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty) return;

    setState(() => _sending = true);

    final nombre = _nombreCtrl.text.trim();
    final apellido = _apellidoCtrl.text.trim();
    final name = [nombre, apellido].where((s) => s.isNotEmpty).join(' ');

    final result = await AuthApiService.createInvite(
      email: correo,
      role: 'empleado',
      name: name.isEmpty ? null : name,
      sendEmail: true,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitación enviada por correo al empleado'),
        ),
      );
      widget.onInvited();
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar empleado'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellidoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dniCtrl,
                decoration: const InputDecoration(
                  labelText: 'DNI (opcional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'El correo es obligatorio';
                  if (!s.contains('@') || !s.contains('.')) {
                    return 'Correo inválido';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Invitar'),
        ),
      ],
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
