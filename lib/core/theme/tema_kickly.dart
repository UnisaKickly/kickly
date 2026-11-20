import 'package:flutter/material.dart';

/// Costruisce il tema condiviso dell'app per mantenere coerenti le schermate.
class TemaKickly {
  /// Restituisce il tema Material 3 usato da tutte le rotte dell'app.
  static ThemeData crea() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A3A)),
      useMaterial3: true,
    );
  }
}
