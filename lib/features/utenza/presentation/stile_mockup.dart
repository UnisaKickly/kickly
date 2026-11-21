// Stile dei mock-up del RAD (§3.4.6) per le schermate di accesso
// (KCK-215).
//
// I mock-up (es. UI_7) hanno sfondo nero, card grigio scuro, accento lime
// #CAFF00 e pulsanti a pillola, mentre il tema condiviso TemaKickly
// (lib/core/theme, KCK-194) e' ancora chiaro e verde. Cambiare il tema
// condiviso e' fuori dall'ambito di KCK-215 (lib/core): queste schermate
// applicano lo stile dei mock-up localmente. Quando TemaKickly lo adottera',
// questo file si potra' eliminare.
import 'package:flutter/material.dart';

/// Colori misurati sui mock-up del RAD (UI_7) e accento del team (#CAFF00).
abstract final class ColoriMockup {
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

/// Tema scuro dei mock-up, da applicare con `Theme(data: ...)` attorno a una
/// schermata.
ThemeData temaMockup() {
  final ColorScheme schema = const ColorScheme.dark().copyWith(
    primary: ColoriMockup.accento,
    onPrimary: Colors.black,
    surface: ColoriMockup.sfondo,
    onSurface: ColoriMockup.testo,
    error: ColoriMockup.errore,
  );
  final OutlineInputBorder bordoCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: ColoriMockup.bordo),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    scaffoldBackgroundColor: ColoriMockup.sfondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoriMockup.sfondo,
      foregroundColor: ColoriMockup.testo,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: ColoriMockup.testo,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      shape: Border(bottom: BorderSide(color: ColoriMockup.bordo)),
    ),
    cardTheme: CardThemeData(
      color: ColoriMockup.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColoriMockup.bordo),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoriMockup.campo,
      hintStyle: const TextStyle(color: ColoriMockup.testoSecondario),
      border: bordoCampo,
      enabledBorder: bordoCampo,
      focusedBorder: bordoCampo.copyWith(
        borderSide: const BorderSide(color: ColoriMockup.accento),
      ),
      errorBorder: bordoCampo.copyWith(
        borderSide: const BorderSide(color: ColoriMockup.errore),
      ),
      focusedErrorBorder: bordoCampo.copyWith(
        borderSide: const BorderSide(color: ColoriMockup.errore),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoriMockup.accento,
        foregroundColor: Colors.black,
        disabledBackgroundColor: ColoriMockup.accento.withValues(alpha: 0.5),
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoriMockup.accento,
        disabledForegroundColor: ColoriMockup.accento.withValues(alpha: 0.6),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: ColoriMockup.testo,
      textColor: ColoriMockup.testo,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: ColoriMockup.testoSecondario, fontSize: 15),
      bodyMedium: TextStyle(color: ColoriMockup.testoSecondario),
      labelMedium: TextStyle(
        color: ColoriMockup.testoSecondario,
        fontSize: 12,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
