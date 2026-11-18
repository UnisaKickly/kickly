// Test di isConfigComplete (lib/core/config/app_config.dart).
//
// La funzione decide se l'app puo' collegarsi a Supabase: deve rifiutare
// valori vuoti o fatti di soli spazi e accettare valori validi.
// Ogni test segue lo schema Arrange / Act / Assert.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/config/app_config.dart';

void main() {
  // Valori fittizi: nessuna chiave reale nei test.
  const urlValido = 'https://progetto-di-prova.supabase.co';
  const chiaveValida = 'chiave-anon-di-prova';

  group('isConfigComplete', () {
    test('restituisce false se entrambi i valori sono vuoti', () {
      expect(isConfigComplete('', ''), isFalse);
    });

    test('restituisce false se l\'URL e\' vuoto', () {
      expect(isConfigComplete('', chiaveValida), isFalse);
    });

    test('restituisce false se la chiave anon e\' vuota', () {
      expect(isConfigComplete(urlValido, ''), isFalse);
    });

    test('restituisce false se l\'URL contiene solo spazi', () {
      expect(isConfigComplete('   ', chiaveValida), isFalse);
    });

    test('restituisce false se la chiave anon contiene solo spazi', () {
      expect(isConfigComplete(urlValido, ' \t\n '), isFalse);
    });

    test('restituisce true se URL e chiave anon sono validi', () {
      expect(isConfigComplete(urlValido, chiaveValida), isTrue);
    });

    test('in test, senza --dart-define, la configurazione e\' incompleta', () {
      // Come in CI: nessun config.json, quindi i valori sono vuoti.
      expect(isConfigComplete(supabaseUrl, supabaseAnonKey), isFalse);
    });
  });
}
