import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_service.dart';

class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key, required this.refreshToken, this.message});

  final String refreshToken;
  final String? message;

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _enrollLoading = true;
  String? _errorMessage;
  String? _factorId;
  String? _qrCode;
  String? _secret;

  @override
  void initState() {
    super.initState();
    _loadEnroll();
  }

  Future<void> _loadEnroll() async {
    try {
      final response = await AuthApiService.mfaEnroll(
        refreshToken: widget.refreshToken,
      );
      if (response.factorId != null &&
          (response.qrCode != null || response.secret != null)) {
        setState(() {
          _factorId = response.factorId;
          _qrCode = response.qrCode;
          _secret = response.secret;
          _enrollLoading = false;
          _errorMessage = response.error;
        });
      } else {
        setState(() {
          _enrollLoading = false;
          _errorMessage = response.error ?? 'Error al cargar 2FA';
        });
      }
    } catch (e) {
      setState(() {
        _enrollLoading = false;
        _errorMessage = 'Error al conectar. Intentá de nuevo.';
      });
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_loading || _factorId == null) return;
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Ingresá el código de 6 dígitos');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthApiService.mfaEnrollVerify(
        refreshToken: widget.refreshToken,
        factorId: _factorId!,
        code: code,
      );

      if (response.result != null) {
        await Supabase.instance.client.auth.setSession(
          response.result!.refreshToken,
        );
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/dashboard', (route) => false);
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = response.error ?? 'Código incorrecto o expirado';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error al verificar. Intentá de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enrollLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Configurando 2FA...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configurar 2FA',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.message ??
                      'Escaneá el código QR con tu app autenticadora (Google Authenticator, Authy, etc.) y luego ingresá el código de 6 dígitos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_qrCode != null || _secret != null) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: _qrCode != null && _qrCode!.trim().startsWith('<svg')
                        ? SvgPicture.string(
                            _qrCode!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          )
                        : Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_2,
                                size: 120,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                  ),
                ],
                if (_secret != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Código manual: $_secret',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Código de 6 dígitos',
                    hintText: '000000',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => _errorMessage = null),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                      : const Text('Confirmar y continuar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
