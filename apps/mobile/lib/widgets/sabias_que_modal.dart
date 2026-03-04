// CFG-039 (sabias_que_frecuencia). P-LEGAL: tips legales.
// Referencia: definiciones/CONFIGURACIONES.md, plan T7.

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages - shared_preferences está en pubspec.yaml de la app
import 'package:shared_preferences/shared_preferences.dart';

import '../core/org_config_provider.dart';

const _storageKey = 'sabias_que_last_shown';

/// Tips legales breves (LCT, Reforma Laboral 2026, validez probatoria).
const _tips = [
  'Los registros de fichaje tienen validez probatoria en juicios laborales cuando cumplen con la normativa (LCT, Reforma Laboral 2026).',
  'El banco de horas y los descansos entre jornadas están regulados por la Ley de Contrato de Trabajo y la Reforma Laboral 2026.',
  'Tu empleador puede configurar la obligatoriedad de geolocalización y del modo offline según la política de la organización.',
];

/// Comprueba si corresponde mostrar el modal según CFG-039 y la última vez mostrado.
Future<bool> _shouldShow(String frequency, SharedPreferences prefs) async {
  final last = prefs.getString(_storageKey);
  final now = DateTime.now();

  switch (frequency) {
    case 'nunca':
      return false;
    case 'siempre':
      return true;
    case 'una_vez_dia':
      if (last == null) return true;
      final lastDate = DateTime.tryParse(last);
      if (lastDate == null) return true;
      return lastDate.year != now.year ||
          lastDate.month != now.month ||
          lastDate.day != now.day;
    case 'una_vez_semana':
      if (last == null) return true;
      final lastDate = DateTime.tryParse(last);
      if (lastDate == null) return true;
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final lastStartOfWeek = lastDate.subtract(Duration(days: lastDate.weekday - 1));
      return startOfWeek.year != lastStartOfWeek.year ||
          startOfWeek.month != lastStartOfWeek.month ||
          startOfWeek.day != lastStartOfWeek.day;
    default:
      return true;
  }
}

void _saveShown(SharedPreferences prefs) {
  prefs.setString(_storageKey, DateTime.now().toIso8601String().substring(0, 10));
}

/// Modal "Sabías que…" (CFG-039, P-LEGAL). Llamar tras cargar el dashboard.
class SabiasQueModal {
  SabiasQueModal._();

  /// Si CFG-039 lo permite y el período lo indica, muestra el modal.
  static Future<void> maybeShow(BuildContext context) async {
    if (!context.mounted) return;
    if (!OrgConfigProvider.isLoaded) return;

    final frequency = OrgConfigProvider.sabiasQueFrecuencia;
    if (frequency == 'nunca') return;

    final prefs = await SharedPreferences.getInstance();
    final show = await _shouldShow(frequency, prefs);
    if (!show || !context.mounted) return;

    final tip = _tips[DateTime.now().millisecondsSinceEpoch % _tips.length];

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Sabías que…'),
        content: SingleChildScrollView(
          child: Text(tip),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveShown(prefs);
              Navigator.of(ctx).pop();
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    _saveShown(prefs);
  }
}
