import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_service.dart';

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
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
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
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

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
    } catch (_) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al actualizar contraseña.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
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
                    'Elegí una contraseña segura para tu cuenta.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Confirmá tu contraseña';
                      if (v != _newPasswordController.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    if (_errorMessage!.contains('expiró')) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/forgot-password'),
                        child: const Text('Solicitar nuevo enlace'),
                      ),
                    ],
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
                        : const Text('Guardar contraseña'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
