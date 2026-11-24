// Widget test del posto dell'errore in FormRegistrazione (KCK-277).
//
// Perche': il messaggio d'errore stava nella barra fissa in basso e, su un
// telefono, restringeva la parte scorrevole tagliando il testo a meta'. Ora
// l'errore sta nel contenuto scorrevole e la barra con il pulsante non cambia
// altezza. Nessun accesso al DB: senza Control la schermata mostra l'errore di
// configurazione, che basta a provare dove compare.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/theme/tema_kickly.dart';
import 'package:kickly/features/utenza/presentation/form_registrazione.dart';

void main() {
  testWidgets('l\'errore compare in vista, sopra il pulsante, senza coprirlo', (
    tester,
  ) async {
    // Preparazione: schermo da telefono (390x700) e modulo senza Control.
    // Azione: tocco su "Crea account" con i campi vuoti.
    // Esito atteso: il messaggio e' visibile dentro lo schermo e finisce sopra
    // il pulsante, che resta dov'era.
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaKickly.crea(),
        home: const FormRegistrazione(control: null),
      ),
    );
    final Finder pulsante = find.byKey(
      const Key('form_registrazione_continua'),
    );
    final Rect pulsantePrima = tester.getRect(pulsante);

    await tester.tap(pulsante);
    await tester.pumpAndSettle();

    final Finder errore = find.byKey(const Key('form_registrazione_errore'));
    expect(errore, findsOneWidget);
    final Rect rettangoloErrore = tester.getRect(errore);
    expect(rettangoloErrore.top, greaterThanOrEqualTo(0));
    expect(rettangoloErrore.bottom, lessThanOrEqualTo(700));
    expect(rettangoloErrore.bottom, lessThanOrEqualTo(pulsantePrima.top));
    expect(tester.getRect(pulsante), pulsantePrima);
  });
}
