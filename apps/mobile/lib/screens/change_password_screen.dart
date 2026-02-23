import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../services/auth_api_service.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/fichar_button.dart';

// P-AUTH-04: Cambio obligatorio de contraseña en primer login.
// Se muestra cuando el backend retorna requires_password_change: true.
// No permite navegar atrás hasta completar el cambio.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.refreshToken});

  final String refreshToken;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setSession();
  }

  Future<void> _setSession() async {
    try {
      await Supabase.instance.client.auth.setSession(widget.refreshToken);
    } catch (e) {
      if (kDebugMode) debugPrint('change_password setSession: $e');
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresá la contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Al menos una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Al menos un número';
    return null;
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'Sesión expirada. Iniciá sesión de nuevo.';
        });
        return;
      }

      final result = await AuthApiService.changePassword(
        token: session.accessToken,
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );

      if (result.error != null) {
        setState(() {
          _loading = false;
          _errorMessage = result.error;
        });
        return;
      }

      if (result.refreshToken != null) {
        await Supabase.instance.client.auth.setSession(result.refreshToken!);
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        await Supabase.instance.client.auth.signOut();
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada. Iniciá sesión con tu nueva contraseña.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('change_password submit: $e');
      setState(() {
        _loading = false;
        _errorMessage = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentMaxWidth = 440.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambiar contraseña'),
          automaticallyImplyLeading: false,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              color: theme.colorScheme.surface,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(kSpacingLg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: Container(
                        padding: const EdgeInsets.all(kSpacingLg),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(kRadiusXl),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Por seguridad, debés cambiar tu contraseña antes de continuar.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpacingXl),
                              TextFormField(
                                controller: _currentController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Contraseña actual'),
                                validator: (v) =>
                                    (v == null || v.isEmpty) ? 'Ingresá tu contraseña actual' : null,
                              ),
                              const SizedBox(height: kSpacingMd),
                              TextFormField(
                                controller: _newController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: kSpacingMd),
                              TextFormField(
                                controller: _confirmController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Confirmá tu contraseña';
                                  if (v != _newController.text) return 'Las contraseñas no coinciden';
                                  return null;
                                },
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: kSpacingMd),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(color: theme.colorScheme.error),
                                ),
                              ],
                              const SizedBox(height: kSpacingLg),
                              FicharButton(
                                onPressed: _loading ? null : _onSubmit,
                                loading: _loading,
                                child: const Text('Cambiar contraseña'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
