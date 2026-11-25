// Tema condiviso dell'app Kickly (KCK-194, aggiornato da KCK-272).
//
// E' lo stile dei mock-up del RAD (§3.4.6, es. UI_7, UI_LEG_1, UI_LEG_2):
// sfondo nero, card grigio scuro, accento lime #CAFF00 e pulsanti a pillola.
// Prima stava in lib/features/utenza/presentation/stile_mockup.dart (KCK-215)
// e lo usavano solo alcune schermate; ora vale per tutta l'app, cosi' non
// convivono due stili diversi.
import 'package:flutter/material.dart';

/// Colori misurati sui mock-up del RAD (UI_7) e accento del team (#CAFF00).
abstract final class ColoriKickly {
  /// Sfondo delle schermate.
  static const sfondo = Color(0xFF0B0B0B);

  /// Sfondo delle card.
  static const card = Color(0xFF151517);

  /// Sfondo dei campi di testo.
  static const campo = Color(0xFF1E1E20);

  /// Bordi sottili di card e campi.
  static const bordo = Color(0xFF2A2A2D);

  /// Accento lime: pulsanti principali e link.
  static const accento = Color(0xFFCAFF00);

  /// Testo principale.
  static const testo = Color(0xFFF2F2F2);

  /// Testo secondario, etichette e suggerimenti.
  static const testoSecondario = Color(0xFF9A9AA0);

  /// Errori.
  static const errore = Color(0xFFFF6B6B);
}

/// Costruisce il tema condiviso dell'app per mantenere coerenti le schermate.
abstract final class TemaKickly {
  /// Restituisce il tema scuro dei mock-up usato da tutte le rotte dell'app.
  static ThemeData crea() {
    final ColorScheme schema = const ColorScheme.dark().copyWith(
      primary: ColoriKickly.accento,
      onPrimary: Colors.black,
      surface: ColoriKickly.sfondo,
      onSurface: ColoriKickly.testo,
      error: ColoriKickly.errore,
    );
    final OutlineInputBorder bordoCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColoriKickly.bordo),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: schema,
      scaffoldBackgroundColor: ColoriKickly.sfondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoriKickly.sfondo,
        foregroundColor: ColoriKickly.testo,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ColoriKickly.testo,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(bottom: BorderSide(color: ColoriKickly.bordo)),
      ),
      cardTheme: CardThemeData(
        color: ColoriKickly.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ColoriKickly.bordo),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoriKickly.campo,
        hintStyle: const TextStyle(color: ColoriKickly.testoSecondario),
        border: bordoCampo,
        enabledBorder: bordoCampo,
        focusedBorder: bordoCampo.copyWith(
          borderSide: const BorderSide(color: ColoriKickly.accento),
        ),
        errorBorder: bordoCampo.copyWith(
          borderSide: const BorderSide(color: ColoriKickly.errore),
        ),
        focusedErrorBorder: bordoCampo.copyWith(
          borderSide: const BorderSide(color: ColoriKickly.errore),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColoriKickly.accento,
          foregroundColor: Colors.black,
          disabledBackgroundColor: ColoriKickly.accento.withValues(alpha: 0.5),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColoriKickly.accento,
          disabledForegroundColor: ColoriKickly.accento.withValues(alpha: 0.6),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ColoriKickly.testo,
        textColor: ColoriKickly.testo,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: ColoriKickly.testoSecondario, fontSize: 15),
        bodyMedium: TextStyle(color: ColoriKickly.testoSecondario),
        labelMedium: TextStyle(
          color: ColoriKickly.testoSecondario,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
