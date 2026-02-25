import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../services/me_api_service.dart';
import '../theme.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

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
  String? _devicesError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _devicesError = null;
    });

    final meResult = await MeApiService.getMe();
    if (!mounted) return;
    if (meResult.error != null) {
      setState(() {
        _loading = false;
        _error = meResult.error;
        _me = null;
        _devices = [];
      });
      return;
    }

    final devicesResult = await MeApiService.getDevices();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _me = meResult.result;
      _devices = devicesResult.devices ?? [];
      _devicesError = devicesResult.error;
    });
  }

  Future<void> _loadDevicesOnly() async {
    setState(() => _devicesError = null);
    final result = await MeApiService.getDevices();
    if (!mounted) return;
    setState(() {
      _devices = result.devices ?? [];
      _devicesError = result.error;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dispositivo revocado')));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Error al revocar')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      try {
        await Supabase.instance.client.auth.signOut(
          scope: SignOutScope.local,
        );
      } catch (_) {}
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

  bool get _isSessionExpired =>
      _error == MeApiService.sessionExpiredError;

  bool get _isProfileEmpty =>
      _me != null &&
      (_me!.name == null || _me!.name!.trim().isEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_loading && _isSessionExpired) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tu sesión expiró.',
                  style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Volvé a iniciar sesión para continuar.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _loading
          ? _buildSkeletonLoading(theme)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ResponsiveContentWrapper(
                  width: ContentWidth.formWide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null && !_isSessionExpired) ...[
                          InlineError(
                            message: _error!,
                            onRetry: _loadData,
                            isLoading: false,
                          ),
                          const SizedBox(height: kSpacingMd),
                        ],
                        if (_me != null && _isProfileEmpty)
                          _buildCompleteProfileBanner(theme),
                        if (_me != null && _isProfileEmpty)
                          const SizedBox(height: kSpacingMd),
                        if (_me != null) _buildProfileCard(theme),
                        const SizedBox(height: kSpacingLg),
                        _buildDevicesCard(theme, _devicesError, _loadDevicesOnly),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCompleteProfileBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(kSpacingLg),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenido!, completemos tu perfil!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: kSpacingSm),
          Text(
            'Agregá tu foto, teléfono y datos para que tu equipo te reconozca.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    return SingleChildScrollView(
      child: ResponsiveContentWrapper(
        width: ContentWidth.formWide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: kSpacingLg),
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

  Widget _buildDevicesCard(
    ThemeData theme,
    String? devicesError,
    VoidCallback onRetryDevices,
  ) {
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
          if (devicesError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: kSpacingMd),
              child: InlineError(
                message: 'No se pudieron cargar los dispositivos.',
                onRetry: onRetryDevices,
                isLoading: false,
              ),
            )
          else if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: kSpacingLg),
              child: Row(
                children: [
                  Icon(Icons.phone_android_outlined, size: 24),
                  SizedBox(width: kSpacingMd),
                  Text('Este es tu dispositivo actual'),
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
                    label:
                        'Revocar ${d.current ? "este dispositivo" : "dispositivo"}',
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
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
