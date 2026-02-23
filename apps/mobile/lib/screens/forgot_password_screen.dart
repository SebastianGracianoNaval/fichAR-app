import 'package:flutter/material.dart';

import '../core/device_capabilities.dart';
import '../services/auth_api_service.dart';
import '../theme.dart';
import '../widgets/fichar_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_loading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final result = await AuthApiService.forgotPassword(
        email: _emailController.text.trim(),
      );
      setState(() {
        _loading = false;
        if (result.error == null) {
          _sent = true;
        } else {
          _errorMessage = result.error;
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al enviar. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentMaxWidth = 440.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contrasena'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                      child: _sent ? _buildSuccess(context) : _buildForm(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: kSpacingLg),
        Text(
          'Si el email existe, recibiras un enlace en minutos.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpacingXl),
        FicharButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver al login'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ingresa tu email y te enviaremos un enlace para restablecer tu contrasena.',
            style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpacingXl),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'tu@email.com',
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu email';
              if (!v.contains('@')) return 'Email invalido';
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
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }
}
