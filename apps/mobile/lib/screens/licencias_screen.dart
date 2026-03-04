import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/org_config_provider.dart';
import '../theme.dart';
import '../services/licencias_api_service.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

const _maxAdjuntoBytes = 5 * 1024 * 1024; // 5 MB (CL-017)
const _adjuntoExtensiones = ['pdf', 'jpg', 'jpeg', 'png'];
const _msgAdjuntoObligatorio =
    'Para licencias por enfermedad o accidente debés adjuntar el certificado médico.';
const _msgAdjuntoFormato =
    'Solo se permiten archivos PDF, JPG o PNG de hasta 5 MB.';
const _tiposRequierenAdjunto = ['enfermedad', 'accidente'];

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
  late String _formTipo;
  DateTime? _formFechaInicio;
  DateTime? _formFechaFin;
  final _motivoCtrl = TextEditingController();
  List<int>? _adjuntoBytes;
  String? _adjuntoFilename;

  @override
  void initState() {
    super.initState();
    _formTipo = OrgConfigProvider.licenciasTiposPermitidos.isNotEmpty
        ? OrgConfigProvider.licenciasTiposPermitidos.first
        : 'enfermedad';
    _loadLicencias();
  }

  List<String> get _tiposLicencia => OrgConfigProvider.licenciasTiposPermitidos;

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
              onPressed: () => setState(() {
                _showForm = true;
                _adjuntoBytes = null;
                _adjuntoFilename = null;
              }),
            ),
        ],
      ),
      body: _showForm
          ? _buildForm()
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ResponsiveContentWrapper(
              width: ContentWidth.list,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                child: InlineError(
                  message: _error!,
                  onRetry: _loadLicencias,
                  isLoading: false,
                ),
              ),
            )
          : _licencias.isEmpty
          ? ResponsiveContentWrapper(
              width: ContentWidth.list,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: kSpacingMd),
                    Text(
                      'No tenés solicitudes',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: kSpacingLg),
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _showForm = true;
                        _adjuntoBytes = null;
                        _adjuntoFilename = null;
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva solicitud'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLicencias,
              child: ResponsiveContentWrapper(
                width: ContentWidth.list,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                  itemCount: _licencias.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: FilledButton.icon(
                          onPressed: () => setState(() {
                            _showForm = true;
                            _adjuntoBytes = null;
                            _adjuntoFilename = null;
                          }),
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
                        title: Text(
                          '${l['tipo']} - ${l['fecha_inicio']} / ${l['fecha_fin']}',
                        ),
                        subtitle: Text(estado),
                        trailing: Chip(
                          label: Text(
                            estado,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: color.withValues(alpha: 0.2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  bool get _requiereAdjunto =>
      OrgConfigProvider.licenciasAdjuntoObligatorio &&
      _tiposRequierenAdjunto.contains(_formTipo);

  Widget _buildAdjuntoSection() {
    final requiere = _requiereAdjunto;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requiere)
          Text(
            'Certificado médico (obligatorio)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        const SizedBox(height: kSpacingSm),
        if (_adjuntoBytes != null && _adjuntoFilename != null)
          Chip(
            avatar: const Icon(Icons.attach_file, size: 20),
            label: Text(_adjuntoFilename!),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () => setState(() {
              _adjuntoBytes = null;
              _adjuntoFilename = null;
            }),
          )
        else
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Adjuntar certificado'),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: _adjuntoExtensiones,
                withData: true,
              );
              if (!mounted || result == null || result.files.isEmpty) return;
              final file = result.files.single;
              final bytes = file.bytes;
              final name = file.name;
              if (bytes == null || name.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(_msgAdjuntoFormato)),
                );
                return;
              }
              final ext = name.split('.').last.toLowerCase();
              if (!_adjuntoExtensiones.any((e) => e == ext)) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(_msgAdjuntoFormato)),
                );
                return;
              }
              if (bytes.length > _maxAdjuntoBytes) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(_msgAdjuntoFormato)),
                );
                return;
              }
              setState(() {
                _adjuntoBytes = bytes;
                _adjuntoFilename = name;
              });
            },
          ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (_formFechaInicio == null || _formFechaFin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná fecha inicio y fin')),
      );
      return;
    }
    if (_formFechaFin!.isBefore(_formFechaInicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fecha fin debe ser >= fecha inicio'),
        ),
      );
      return;
    }
    if (_requiereAdjunto && (_adjuntoBytes == null || _adjuntoFilename == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(_msgAdjuntoObligatorio)),
      );
      return;
    }
    List<Map<String, String>>? adjuntos;
    if (_adjuntoBytes != null && _adjuntoFilename != null) {
      final upload = await LicenciasApiService.uploadAdjunto(
        _adjuntoBytes!,
        filename: _adjuntoFilename!,
      );
      if (!mounted) return;
      if (upload.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(upload.error!)),
        );
        return;
      }
      adjuntos = [upload.data!.toJson()];
    }
    final fi =
        '${_formFechaInicio!.year}-${_formFechaInicio!.month.toString().padLeft(2, '0')}-${_formFechaInicio!.day.toString().padLeft(2, '0')}';
    final ff =
        '${_formFechaFin!.year}-${_formFechaFin!.month.toString().padLeft(2, '0')}-${_formFechaFin!.day.toString().padLeft(2, '0')}';
    final result = await LicenciasApiService.createLicencia(
      tipo: _formTipo,
      fechaInicio: fi,
      fechaFin: ff,
      motivo: _motivoCtrl.text.trim().isEmpty
          ? null
          : _motivoCtrl.text.trim(),
      adjuntos: adjuntos,
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
      _adjuntoBytes = null;
      _adjuntoFilename = null;
      _licencias.insert(0, result.data!);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitud enviada')),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: ResponsiveContentWrapper(
        width: ContentWidth.formWide,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacingMd,
            vertical: kSpacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tiposLicencia.contains(_formTipo)
                    ? _formTipo
                    : (_tiposLicencia.isNotEmpty
                        ? _tiposLicencia.first
                        : 'enfermedad'),
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: _tiposLicencia
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _formTipo = v ?? _formTipo),
              ),
              const SizedBox(height: kSpacingMd),
              _buildAdjuntoSection(),
              const SizedBox(height: kSpacingMd),
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
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _formFechaInicio = d);
                },
              ),
              const SizedBox(height: kSpacingSm),
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
                    initialDate:
                        _formFechaFin ?? _formFechaInicio ?? DateTime.now(),
                    firstDate:
                        _formFechaInicio ??
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _formFechaFin = d);
                },
              ),
              const SizedBox(height: kSpacingMd),
              TextField(
                controller: _motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: kSpacingLg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showForm = false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: kSpacingMd),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitForm,
                      child: const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
