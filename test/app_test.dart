// Primo test di esempio (widget test).
//
// Serve a due cose:
//  1. dimostrare che `flutter test` gira in locale e in CI;
//  2. fare da modello per i test che il team scrivera' (vedi Test Case
//     Specification). Ogni test segue lo schema Arrange / Act / Assert.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';

void main() {
  testWidgets('la home mostra il messaggio di benvenuto', (tester) async {
    // Arrange + Act: costruisce l'app e attende il primo frame.
    await tester.pumpWidget(const KicklyApp());

    // Assert: il testo e l'icona attesi sono presenti a schermo.
    expect(find.text('Ciao da Kickly!'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });
}
