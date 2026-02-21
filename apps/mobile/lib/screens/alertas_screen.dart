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
    final ids = result.data.map((e) => e['employee_id'] as String).toSet().toList();
    if (ids.isNotEmpty) {
      try {
        final empResult = await EmployeesApiService.getEmployees();
        for (final e in empResult.data) {
          _nombres[e.id] = e.name;
        }
      } catch (_) {}
    }
    setState(() {
      _loading = false;
      _alertas = result.data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Reintentar')),
                    ],
                  ),
                )
              : _alertas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No hay alertas', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alertas.length,
                        itemBuilder: (context, i) {
                          final a = _alertas[i];
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
                                color: _colorForTipo(tipo),
                              ),
                              title: Text(nombre),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tipo, style: Theme.of(context).textTheme.labelMedium),
                                  if (desc.isNotEmpty) Text(desc),
                                  Text(created.length > 19 ? created.substring(0, 19) : created,
                                      style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  IconData _iconForTipo(String tipo) {
    if (tipo.contains('descanso')) return Icons.bedtime;
    if (tipo.contains('banco')) return Icons.schedule;
    if (tipo.contains('zona')) return Icons.location_off;
    return Icons.warning;
  }

  Color _colorForTipo(String tipo) {
    if (tipo.contains('descanso')) return Colors.orange;
    if (tipo.contains('banco')) return Colors.amber;
    if (tipo.contains('zona')) return Colors.red;
    return Colors.blue;
  }
}
