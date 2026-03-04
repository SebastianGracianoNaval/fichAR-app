import 'package:flutter/material.dart';

import '../services/licencias_api_service.dart';
import '../services/employees_api_service.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<Map<String, dynamic>> _alertas = [];
  String? _error;
  bool _loading = true;
  final Map<String, String> _nombres = {};

  String? _filterTipo;
  String? _filterEmpleado;
  DateTime? _filterDesde;
  DateTime? _filterHasta;

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
    final result = await LicenciasApiService.getAlertas();
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _loading = false;
        _error = result.error;
      });
      return;
    }
    final ids = result.data
        .map((e) => e['employee_id'] as String)
        .toSet()
        .toList();
    if (ids.isNotEmpty) {
      try {
        final empResult = await EmployeesApiService.getEmployees();
        for (final e in empResult.data) {
          _nombres[e.id] = e.name;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al cargar nombres de empleados. Reintentá.'),
            ),
          );
        }
      }
    }
    setState(() {
      _loading = false;
      _alertas = result.data;
    });
  }

  Set<String> get _tiposDisponibles {
    return _alertas
        .map((a) => _categorizeTipo(a['tipo'] as String? ?? ''))
        .toSet();
  }

  List<String> get _empleadosConAlertas {
    final ids = <String>{};
    for (final a in _alertas) {
      final id = a['employee_id'] as String?;
      if (id != null) ids.add(id);
    }
    final sorted = ids.toList()
      ..sort((a, b) {
        final na = _nombres[a] ?? a;
        final nb = _nombres[b] ?? b;
        return na.compareTo(nb);
      });
    return sorted;
  }

  List<Map<String, dynamic>> get _filteredAlertas {
    return _alertas.where((a) {
      final tipo = a['tipo'] as String? ?? '';
      final empId = a['employee_id'] as String?;

      if (_filterTipo != null &&
          _categorizeTipo(tipo) != _filterTipo) {
        return false;
      }
      if (_filterEmpleado != null && empId != _filterEmpleado) {
        return false;
      }
      final createdStr = a['created_at'] as String?;
      if (createdStr != null && createdStr.isNotEmpty) {
        final created = DateTime.tryParse(createdStr);
        if (created != null) {
          final day = DateTime(created.year, created.month, created.day);
          if (_filterDesde != null && day.isBefore(_filterDesde!)) return false;
          if (_filterHasta != null && day.isAfter(_filterHasta!)) return false;
        }
      }
      return true;
    }).toList();
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _categorizeTipo(String tipo) {
    if (tipo.contains('descanso')) return 'descanso';
    if (tipo.contains('banco')) return 'banco';
    if (tipo.contains('zona')) return 'zona';
    return 'otro';
  }

  String _tipoLabel(String cat) {
    switch (cat) {
      case 'descanso':
        return 'Descanso';
      case 'banco':
        return 'Banco';
      case 'zona':
        return 'Zona';
      default:
        return 'Otro';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: const Text('Alertas'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar alertas',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _alertas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay alertas',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _buildFilterBar(theme),
                        Expanded(child: _buildList(theme)),
                      ],
                    ),
    );
  }

  Future<void> _pickDate(bool isDesde) async {
    final initial = isDesde ? _filterDesde : _filterHasta;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isDesde) {
        _filterDesde = picked;
        if (_filterHasta != null && _filterHasta!.isBefore(picked)) {
          _filterHasta = picked;
        }
      } else {
        _filterHasta = picked;
        if (_filterDesde != null && _filterDesde!.isAfter(picked)) {
          _filterDesde = picked;
        }
      }
    });
  }

  Widget _buildFilterBar(ThemeData theme) {
    final tipos = _tiposDisponibles.toList()..sort();
    final empleados = _empleadosConAlertas;
    final hasFilters = _filterTipo != null ||
        _filterEmpleado != null ||
        _filterDesde != null ||
        _filterHasta != null;
    final filtered = _filteredAlertas;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // P-SUP-03: filtro por rango de fechas
                Tooltip(
                  message: 'Desde',
                  child: IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () => _pickDate(true),
                  ),
                ),
                Tooltip(
                  message: 'Hasta',
                  child: IconButton(
                    icon: const Icon(Icons.event, size: 20),
                    onPressed: () => _pickDate(false),
                  ),
                ),
                if (_filterDesde != null || _filterHasta != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${_filterDesde != null ? _formatDate(_filterDesde!) : '…'} - ${_filterHasta != null ? _formatDate(_filterHasta!) : '…'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(width: 8),
                // P-SUP-03: filtro por tipo
                ...tipos.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_tipoLabel(t)),
                    selected: _filterTipo == t,
                    onSelected: (sel) {
                      setState(() => _filterTipo = sel ? t : null);
                    },
                  ),
                )),
                if (tipos.length > 1)
                  const SizedBox(width: 8),
                // P-SUP-03: filtro por empleado
                if (empleados.length > 1)
                  PopupMenuButton<String?>(
                    tooltip: 'Filtrar por empleado',
                    onSelected: (val) {
                      setState(() => _filterEmpleado = val);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: null,
                        child: Text('Todos'),
                      ),
                      ...empleados.map((id) => PopupMenuItem(
                        value: id,
                        child: Text(_nombres[id] ?? id),
                      )),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.person, size: 18),
                      label: Text(
                        _filterEmpleado != null
                            ? (_nombres[_filterEmpleado!] ??
                                _filterEmpleado!)
                            : 'Empleado',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasFilters)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} de ${_alertas.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterTipo = null;
                        _filterEmpleado = null;
                        _filterDesde = null;
                        _filterHasta = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    final items = _filteredAlertas;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'Sin alertas para este filtro',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final a = items[i];
          final empId = a['employee_id'] as String?;
          final nombre = _nombres[empId] ?? empId ?? '-';
          final tipo = a['tipo'] as String? ?? '';
          final desc = a['descripcion'] as String? ?? '';
          final created = a['created_at'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                _iconForTipo(tipo),
                color: _colorForTipo(context, tipo),
              ),
              title: Text(nombre),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo,
                    style: theme.textTheme.labelMedium,
                  ),
                  if (desc.isNotEmpty) Text(desc),
                  Text(
                    created.length > 19
                        ? created.substring(0, 19)
                        : created,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForTipo(String tipo) {
    if (tipo.contains('descanso')) return Icons.bedtime;
    if (tipo.contains('banco')) return Icons.schedule;
    if (tipo.contains('zona')) return Icons.location_off;
    return Icons.warning;
  }

  Color _colorForTipo(BuildContext context, String tipo) {
    if (tipo.contains('descanso')) return Colors.orange;
    if (tipo.contains('banco')) return Colors.amber;
    if (tipo.contains('zona')) return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }
}
