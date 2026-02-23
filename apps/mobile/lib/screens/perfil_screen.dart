import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../services/me_api_service.dart';
import '../theme.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  MeResult? _me;
  List<DeviceSession> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final results = await Future.wait([
      MeApiService.getMe(),
      MeApiService.getDevices(),
    ]);

    if (!mounted) return;

    final meResult = results[0] as (MeResult?, String?);
    final devicesResult = results[1] as (List<DeviceSession>?, String?);

    setState(() {
      _loading = false;
      _me = meResult.$1;
      _error = meResult.$2 ?? devicesResult.$2;
      _devices = devicesResult.$1 ?? [];
    });
  }

  Future<void> _revokeDevice(DeviceSession device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar dispositivo'),
        content: Text(
          device.current
              ? 'Se cerrará la sesión en este dispositivo. ¿Continuar?'
              : 'Se cerrará la sesión en ese dispositivo. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (DeviceCapabilities.hasHaptics) {
      HapticFeedback.mediumImpact();
    }

    final result = await MeApiService.revokeDevice(device.id);
    if (!mounted) return;

    if (result.ok) {
      if (device.current) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        return;
      }
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispositivo revocado')),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Error al revocar')),
        );
      }
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: _loading
          ? _buildSkeletonLoading(theme)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth > 440 ? 440.0 : constraints.maxWidth;
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(kSpacingMd),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: kSpacingMd),
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: theme.colorScheme.error),
                                ),
                              ),
                            if (_me != null) _buildProfileCard(theme),
                            const SizedBox(height: kSpacingLg),
                            _buildDevicesCard(theme),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    final maxWidth = 440.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kSpacingMd),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                ),
              ),
              const SizedBox(height: kSpacingLg),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(kSpacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos personales', style: theme.textTheme.titleMedium),
          const SizedBox(height: kSpacingMd),
          _ProfileRow(label: 'Nombre', value: _me!.name ?? '—'),
          const SizedBox(height: kSpacingSm),
          _ProfileRow(label: 'Email', value: _me!.email),
          const SizedBox(height: kSpacingSm),
          _ProfileRow(label: 'CUIL', value: _me!.cuil ?? '—'),
        ],
      ),
    );
  }

  Widget _buildDevicesCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(kSpacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: DeviceCapabilities.isLowEnd
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dispositivos', style: theme.textTheme.titleMedium),
          const SizedBox(height: kSpacingMd),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: kSpacingLg),
              child: Row(
                children: [
                  Icon(Icons.phone_android_outlined, size: 24),
                  SizedBox(width: kSpacingMd),
                  Text('No hay otros dispositivos'),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _devices.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = _devices[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: kSpacingSm,
                  ),
                  minVerticalPadding: 0,
                  leading: const Icon(Icons.phone_android),
                  title: Text(
                    d.current ? 'Este dispositivo' : 'Dispositivo',
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    _formatDate(d.updatedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Semantics(
                    button: true,
                    label: 'Revocar ${d.current ? "este dispositivo" : "dispositivo"}',
                    child: TextButton(
                      onPressed: () => _revokeDevice(d),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(88, 48),
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: const Text('Revocar'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
