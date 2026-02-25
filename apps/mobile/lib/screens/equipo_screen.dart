import 'package:flutter/material.dart';

import '../services/employees_api_service.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive_content_wrapper.dart';
import '../widgets/screen_error_view.dart';

class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Equipo'),
        actions: [
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
                message: 'Error al cargar tu equipo.',
                subtitle: 'Revisá tu conexión e intentá de nuevo.',
                onAction: _load,
                contentWidth: ContentWidth.list,
              ),
            )
          : _employees.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Aún no hay empleados en tu equipo.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: _employees.length,
              itemBuilder: (_, i) {
                final e = _employees[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.email} - ${e.role}'),
                  trailing: Chip(
                    label: Text(e.status),
                    backgroundColor: e.status == 'activo'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                );
              },
            ),
    );
  }
}
