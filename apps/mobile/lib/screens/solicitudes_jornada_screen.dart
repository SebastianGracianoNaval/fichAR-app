import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/solicitudes_jornada_api_service.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive_content_wrapper.dart';

class SolicitudesJornadaScreen extends StatefulWidget {
  const SolicitudesJornadaScreen({super.key, required this.role});

  final String role;

  @override
  State<SolicitudesJornadaScreen> createState() => _SolicitudesJornadaScreenState();
}

class _SolicitudesJornadaScreenState extends State<SolicitudesJornadaScreen> {
  List<SolicitudJornada> _list = [];
  bool _loading = true;
  String? _error;
  static const _adminRoles = ['admin', 'supervisor'];

  bool get _canApprove => _adminRoles.contains(widget.role);

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
      final result = await SolicitudesJornadaApiService.getSolicitudes(
        estado: _canApprove ? 'pendiente' : null,
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _list = result.data;
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

  Future<void> _createSolicitud() async {
    String? tipo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Trabajar más hoy'),
              onTap: () => Navigator.pop(ctx, 'mas_horas'),
            ),
            ListTile(
              title: const Text('Trabajar menos hoy'),
              onTap: () => Navigator.pop(ctx, 'menos_horas'),
            ),
          ],
        ),
      ),
    );
    if (tipo == null || !mounted) return;

    try {
      await SolicitudesJornadaApiService.create(tipo: tipo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud enviada')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatApiError(e))),
      );
    }
  }

  Future<void> _rejectWithMotivo(SolicitudJornada s) async {
    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo (obligatorio)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final t = motivoCtrl.text.trim();
              if (t.isEmpty) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (motivo == null || !mounted) return;

    final result = await SolicitudesJornadaApiService.patch(
      id: s.id,
      estado: 'rechazada',
      motivoRechazo: motivo,
    );
    if (!mounted) return;
    if (result.ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud rechazada')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error')),
      );
    }
  }

  Future<void> _approve(SolicitudJornada s) async {
    final result = await SolicitudesJornadaApiService.patch(
      id: s.id,
      estado: 'aprobada',
    );
    if (!mounted) return;
    if (result.ok) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud aprobada')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_canApprove ? 'Solicitudes pendientes' : 'Mis solicitudes'),
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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _list.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.schedule_send,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _canApprove
                                        ? 'No hay solicitudes pendientes'
                                        : 'No tenés solicitudes',
                                    style: theme.textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ResponsiveContentWrapper(
                          width: ContentWidth.list,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            itemBuilder: (_, i) {
                              final s = _list[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(s.tipoLabel),
                                  subtitle: Text(
                                    '${s.fechaSolicitud} - ${s.estado}'
                                    '${s.motivoRechazo != null ? "\nRechazo: ${s.motivoRechazo}" : ""}',
                                  ),
                                  trailing: _canApprove && s.estado == 'pendiente'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check),
                                              onPressed: () => _approve(s),
                                              tooltip: 'Aprobar',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () => _rejectWithMotivo(s),
                                              tooltip: 'Rechazar',
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                ),
      floatingActionButton: !_canApprove
          ? FloatingActionButton(
              onPressed: _loading ? null : _createSolicitud,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
