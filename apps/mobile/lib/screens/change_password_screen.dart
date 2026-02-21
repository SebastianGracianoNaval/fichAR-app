import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_service.dart';

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
    } catch (_) {
      // Session already set or will be handled on submit
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

      setState(() => _loading = false);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al cambiar contraseña. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambiar contraseña'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Por seguridad, debés cambiar tu contraseña antes de continuar.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _currentController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña actual'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Ingresá tu contraseña actual' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _onSubmit,
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cambiar contraseña'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
