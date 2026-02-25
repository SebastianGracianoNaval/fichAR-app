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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await AuthApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.mfaEnrollmentRequired != null) {
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/mfa-enroll',
          arguments: response.mfaEnrollmentRequired!,
        );
        return;
      }

      if (response.mfaVerificationRequired != null) {
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/mfa-verify',
          arguments: response.mfaVerificationRequired!,
        );
        return;
      }

      if (response.passwordChangeRequired != null) {
        setState(() => _loading = false);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          '/change-password',
          arguments: response.passwordChangeRequired!,
        );
        return;
      }

      if (response.result == null) {
        setState(() {
          _loading = false;
          if (response.statusCode == 429) {
            _errorMessage = 'Demasiados intentos. Intentá en 15 minutos.';
          } else if (response.statusCode == 401) {
            _errorMessage = 'Email o contrasena incorrectos.';
          } else {
            _errorMessage =
                response.error ?? 'Error al iniciar sesion. Intentá de nuevo.';
          }
        });
        return;
      }

      final authResponse = await Supabase.instance.client.auth.setSession(
        response.result!.refreshToken,
      );
      if (authResponse.session == null) {
        throw Exception('No se pudo establecer la sesión');
      }
    } on AuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.message == 'Invalid login credentials'
            ? 'Email o contrasena incorrectos.'
            : e.message;
      });
      return;
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al iniciar sesion. Intentá de nuevo.';
      });
      return;
    }

    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final padding = MediaQuery.sizeOf(context).width >= kBreakpointTablet
        ? kSpacingLg
        : kSpacingMd;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: surface,
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
                              Semantics(
                                header: true,
                                child: Text(
                                  'fichAR',
                                  style: theme.textTheme.headlineLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: kSpacingSm),
                              Text(
                                'Inicio de sesion',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: kSpacingXxl),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_passwordFocusNode);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'tu@email.com',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ingresa tu email';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Email invalido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: kSpacingMd),
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_loading) _onSubmit();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Contrasena',
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ingresa tu contrasena';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: kSpacingSm),
                              Semantics(
                                label: 'Mostrar contrasena',
                                child: CheckboxListTile(
                                  value: !_obscurePassword,
                                  onChanged: (value) {
                                    setState(() => _obscurePassword = value != true);
                                    if (DeviceCapabilities.hasHaptics) {
                                      HapticFeedback.selectionClick();
                                    }
                                  },
                                  title: Text(
                                    'Mostrar contrasena',
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
                              ],
                              const SizedBox(height: kSpacingLg),
                              FicharButton(
                                onPressed: _loading ? null : _onSubmit,
                                loading: _loading,
                                child: const Text('Iniciar sesion'),
                              ),
                              const SizedBox(height: kSpacingMd),
                              TextButton(
                                onPressed: () {
                                  if (DeviceCapabilities.hasHaptics) {
                                    HapticFeedback.selectionClick();
                                  }
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/forgot-password');
                                },
                                child: const Text('Olvide mi contrasena'),
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
