import 'package:flutter/material.dart';

import '../services/licencias_api_service.dart';
import '../services/employees_api_service.dart';

class LicenciasAprobarScreen extends StatefulWidget {
  const LicenciasAprobarScreen({super.key});

  @override
  State<LicenciasAprobarScreen> createState() => _LicenciasAprobarScreenState();
}

class _LicenciasAprobarScreenState extends State<LicenciasAprobarScreen> {
  List<Map<String, dynamic>> _pendientes = [];
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
    final result = await LicenciasApiService.getLicenciasPendientes();
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
      _pendientes = result.data;
    });
  }

  Future<void> _aprobar(String id) async {
    final result = await LicenciasApiService.aprobarLicencia(id);
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    setState(() => _pendientes.removeWhere((e) => e['id'] == id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Licencia aprobada')));
  }

  Future<void> _rechazar(String id) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Motivo del rechazo'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Mínimo 10 caracteres',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().length >= 10) {
                  Navigator.pop(ctx, ctrl.text.trim());
                }
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || !mounted) return;
    final result = await LicenciasApiService.rechazarLicencia(id, motivo);
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    setState(() => _pendientes.removeWhere((e) => e['id'] == id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Licencia rechazada')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobar licencias'),
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
              : _pendientes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 16),
                          Text('No hay solicitudes pendientes', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendientes.length,
                        itemBuilder: (context, i) {
                          final l = _pendientes[i];
                          final empId = l['employee_id'] as String?;
                          final nombre = _nombres[empId] ?? empId ?? '-';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(nombre),
                              subtitle: Text(
                                '${l['tipo']} - ${l['fecha_inicio']} al ${l['fecha_fin']}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () => _aprobar(l['id'] as String),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => _rechazar(l['id'] as String),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
