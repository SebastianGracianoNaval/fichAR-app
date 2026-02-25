import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/device_capabilities.dart';
import '../services/auth_api_service.dart';
import '../theme.dart';
import '../theme/layout_tokens.dart';
import '../widgets/fichar_button.dart';
import '../widgets/inline_error.dart';
import '../widgets/responsive_content_wrapper.dart';

// P-AUTH-03: Nueva contraseña tras click en link de bienvenida o recuperación.
// Triggered when onAuthStateChange emits PASSWORD_RECOVERY.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocusNode = FocusNode();
  bool _loading = false;
  bool _obscurePasswords = true;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Ingresá la nueva contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Al menos una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Al menos un número';
    return null;
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _errorMessage = null);

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Mark password_changed_at on backend (best effort — CL-037: non-blocking)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await AuthApiService.passwordSetComplete(token: session.accessToken);
      }

      setState(() => _loading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Iniciá sesión.')),
      );
      Navigator.of(context).pushReplacementNamed('/login');
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message.contains('expired')
            ? 'El enlace expiró. Solicitá uno nuevo.'
            : 'Error al actualizar contraseña.';
      });
    } catch (e, st) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al actualizar contraseña.';
      });
      assert(() {
        debugPrint('ResetPassword _onSubmit error: $e\n$st');
        return true;
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = MediaQuery.sizeOf(context).width >= kBreakpointTablet
        ? kSpacingLg
        : kSpacingMd;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: padding,
                  vertical: kSpacingMd,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: ResponsiveContentWrapper(
                    width: ContentWidth.form,
                    child: Center(
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
                                'Elegí una contraseña segura para tu cuenta.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpacingXl),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscurePasswords,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context)
                                      .requestFocus(_confirmFocusNode);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Nueva contraseña',
                                ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: kSpacingMd),
                              TextFormField(
                                controller: _confirmController,
                                focusNode: _confirmFocusNode,
                                obscureText: _obscurePasswords,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_loading) _onSubmit();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Confirmá tu contraseña';
                                  }
                                  if (v != _newPasswordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: kSpacingSm),
                              Semantics(
                                label: 'Mostrar contraseña',
                                child: CheckboxListTile(
                                  value: !_obscurePasswords,
                                  onChanged: (value) {
                                    setState(
                                        () => _obscurePasswords = value != true);
                                    if (DeviceCapabilities.hasHaptics) {
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                  title: Text(
                                    'Mostrar contraseña',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: theme.colorScheme.primary,
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: kSpacingMd),
                                InlineError(message: _errorMessage!),
                                if (_errorMessage!.contains('expiró')) ...[
                                  const SizedBox(height: kSpacingSm),
                                  TextButton(
                                    onPressed: () => Navigator.of(context)
                                        .pushReplacementNamed('/forgot-password'),
                                    child: const Text('Solicitar nuevo enlace'),
                                  ),
                                ],
                              ],
                              const SizedBox(height: kSpacingLg),
                              FicharButton(
                                onPressed: _loading ? null : _onSubmit,
                                loading: _loading,
                                child: const Text('Guardar contraseña'),
                              ),
                            ],
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
      ),
    );
  }
}
