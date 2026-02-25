import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/invite_from_url.dart';
import '../services/auth_api_service.dart';
import '../theme.dart';
import '../utils/error_utils.dart';
import '../widgets/responsive_content_wrapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _cuilCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: inviteEmailFromUrl ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _dniCtrl.dispose();
    _cuilCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Mínimo 8 caracteres';
    if (!s.contains(RegExp(r'[A-Z]'))) return 'Al menos una mayúscula';
    if (!s.contains(RegExp(r'[0-9]'))) return 'Al menos un número';
    return null;
  }

  String? _validateCuil(String? v) {
    final s = (v ?? '').replaceAll('-', '').trim();
    if (s.length != 11) return 'CUIL: 11 dígitos (ej. 27-12345678-0)';
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'Solo números';
    return null;
  }

  Future<void> _submit() async {
    _error = null;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = inviteTokenFromUrl;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Enlace inválido o expirado.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await AuthApiService.register(
        inviteToken: token,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
        dni: _dniCtrl.text.trim(),
        cuil: _cuilCtrl.text.trim().replaceAll('-', ''),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result.ok) {
        clearInviteFromUrl();
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada. Iniciá sesión con tu correo y contraseña.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        setState(() => _error = result.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContentWrapper(
          width: ContentWidth.form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingLg, vertical: kSpacingXl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Completar registro',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: kSpacingSm),
                  Text(
                    'Establecé tu contraseña y completá tus datos para acceder a fichAR.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: kSpacingLg),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    readOnly: true,
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Requerido';
                      if (!s.contains('@') || !s.contains('.')) return 'Correo inválido';
                      return null;
                    },
                  ),
                  const SizedBox(height: kSpacingMd),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: kSpacingMd),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: kSpacingMd),
                  TextFormField(
                    controller: _dniCtrl,
                    decoration: const InputDecoration(
                      labelText: 'DNI',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: kSpacingMd),
                  TextFormField(
                    controller: _cuilCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CUIL (11 dígitos, ej. 27-12345678-0)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateCuil,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: kSpacingMd),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: kSpacingLg),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear cuenta'),
                  ),
                  const SizedBox(height: kSpacingMd),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('Ya tengo cuenta'),
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
