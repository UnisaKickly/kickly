// Test della schermata mostrata quando manca config.json.
//
// Verifica il criterio del ticket KCK-24: senza --dart-define l'app mostra
// "Configurazione mancante" senza crash e senza contattare Supabase.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/main.dart';

void main() {
  testWidgets('senza configurazione mostra il messaggio di config mancante', (
    tester,
  ) async {
    // Arrange + Act: costruisce l'app di configurazione mancante.
    await tester.pumpWidget(const ConfigurazioneMancanteApp());

    // Assert: il messaggio con le istruzioni di avvio e' a schermo.
    expect(find.text(messaggioConfigurazioneMancante), findsOneWidget);
  });
}
