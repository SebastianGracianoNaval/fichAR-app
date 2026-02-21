import 'package:flutter/material.dart';

import '../services/licencias_api_service.dart';

const _tiposLicencia = [
  'enfermedad',
  'accidente',
  'matrimonio',
  'maternidad',
  'paternidad',
  'duelo',
  'estudio',
  'otro',
];

class LicenciasScreen extends StatefulWidget {
  const LicenciasScreen({super.key});

  @override
  State<LicenciasScreen> createState() => _LicenciasScreenState();
}

class _LicenciasScreenState extends State<LicenciasScreen> {
  List<Map<String, dynamic>> _licencias = [];
  String? _error;
  bool _loading = true;
  bool _showForm = false;
  String _formTipo = _tiposLicencia.first;
  DateTime? _formFechaInicio;
  DateTime? _formFechaFin;
  final _motivoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLicencias();
  }

  Future<void> _loadLicencias() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await LicenciasApiService.getLicencias();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _licencias = result.data;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Licencias'),
        actions: [
          if (!_showForm)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _showForm = true),
            ),
        ],
      ),
      body: _showForm
          ? _buildForm()
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _loadLicencias, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : _licencias.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No tenés solicitudes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => setState(() => _showForm = true),
                                icon: const Icon(Icons.add),
                                label: const Text('Nueva solicitud'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLicencias,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _licencias.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: FilledButton.icon(
                                    onPressed: () => setState(() => _showForm = true),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nueva solicitud'),
                                  ),
                                );
                              }
                              final l = _licencias[i - 1];
                              final estado = l['estado'] as String? ?? '';
                              final color = estado == 'aprobada'
                                  ? Colors.green
                                  : estado == 'rechazada'
                                      ? Colors.red
                                      : Colors.orange;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text('${l['tipo']} - ${l['fecha_inicio']} / ${l['fecha_fin']}'),
                                  subtitle: Text(estado),
                                  trailing: Chip(
                                    label: Text(estado, style: const TextStyle(fontSize: 12)),
                                    backgroundColor: color.withValues(alpha: 0.2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
    );
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _formTipo,
            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
            items: _tiposLicencia.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _formTipo = v ?? _formTipo),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              _formFechaInicio != null
                  ? '${_formFechaInicio!.year}-${_formFechaInicio!.month.toString().padLeft(2, '0')}-${_formFechaInicio!.day.toString().padLeft(2, '0')}'
                  : 'Fecha inicio',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _formFechaInicio ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _formFechaInicio = d);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(
              _formFechaFin != null
                  ? '${_formFechaFin!.year}-${_formFechaFin!.month.toString().padLeft(2, '0')}-${_formFechaFin!.day.toString().padLeft(2, '0')}'
                  : 'Fecha fin',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _formFechaFin ?? _formFechaInicio ?? DateTime.now(),
                firstDate: _formFechaInicio ?? DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _formFechaFin = d);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _motivoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo (opcional)', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_formFechaInicio == null || _formFechaFin == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seleccioná fecha inicio y fin')),
                      );
                      return;
                    }
                    if (_formFechaFin!.isBefore(_formFechaInicio!)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fecha fin debe ser >= fecha inicio')),
                      );
                      return;
                    }
                    final fi =
                        '${_formFechaInicio!.year}-${_formFechaInicio!.month.toString().padLeft(2, '0')}-${_formFechaInicio!.day.toString().padLeft(2, '0')}';
                    final ff =
                        '${_formFechaFin!.year}-${_formFechaFin!.month.toString().padLeft(2, '0')}-${_formFechaFin!.day.toString().padLeft(2, '0')}';
                    final result = await LicenciasApiService.createLicencia(
                      tipo: _formTipo,
                      fechaInicio: fi,
                      fechaFin: ff,
                      motivo: _motivoCtrl.text.trim().isEmpty ? null : _motivoCtrl.text.trim(),
                    );
                    if (!mounted) return;
                    if (result.error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.error!)),
                      );
                      return;
                    }
                        setState(() {
                          _showForm = false;
                          _licencias.insert(0, result.data!);
                        });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Solicitud enviada')),
                    );
                  },
                  child: const Text('Enviar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
