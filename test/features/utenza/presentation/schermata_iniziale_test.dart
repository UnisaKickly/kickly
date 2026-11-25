// Widget test della schermata iniziale (KCK-277, mock-up UI_1).
//
// Perche': senza i pulsanti "Registrati" e "Accedi" un utente su telefono non
// poteva raggiungere registrazione e login (non c'e' una barra dell'indirizzo).
// Esiti attesi dal mock-up UI_1 e da UC_ACC_1 / RF_ACC_3; nessun accesso al DB.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/provider/autenticazione_provider.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';

/// Avvia l'app non autenticata sulla schermata iniziale e restituisce il router.
///
/// Usa un AutenticazioneControl con repository in memoria: FormLogin lo legge
/// dal provider, quindi serve anche solo per aprire la schermata di login.
Future<AppRouter> _apriSchermataIniziale(WidgetTester tester) async {
  final AutenticazioneControl control = AutenticazioneControl(
    accountRepository: InMemoryAccountRepository(),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [autenticazioneControlProvider.overrideWithValue(control)],
  );
  addTearDown(container.dispose);
  final AppRouter appRouter = AppRouter(
    sessioneProvider: container.read(sessioneAutenticazioneProvider),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: appRouter.router),
    ),
  );
  await tester.pumpAndSettle();
  return appRouter;
}

void main() {
  testWidgets('la schermata iniziale offre Registrati e Accedi (UI_1)', (
    tester,
  ) async {
    // Preparazione: utente non autenticato sulla schermata iniziale.
    // Esito atteso: il benvenuto resta e compaiono i due pulsanti del mock-up.
    await _apriSchermataIniziale(tester);

    expect(find.text('Ciao da Kickly!'), findsOneWidget);
    expect(find.byKey(SchermataIniziale.chiaveRegistrati), findsOneWidget);
    expect(find.byKey(SchermataIniziale.chiaveAccedi), findsOneWidget);
    expect(find.text('Registrati'), findsOneWidget);
    expect(find.text('Accedi'), findsOneWidget);
  });

  testWidgets('Registrati apre la registrazione e indietro torna all\'inizio', (
    tester,
  ) async {
    // Preparazione: schermata iniziale. Azione: tocco su "Registrati".
    // Esito atteso (UC_ACC_1 passo 1-2): si apre il modulo di registrazione;
    // tornando indietro si rivede la schermata iniziale.
    final AppRouter appRouter = await _apriSchermataIniziale(tester);

    await tester.tap(find.byKey(SchermataIniziale.chiaveRegistrati));
    await tester.pumpAndSettle();

    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(find.byType(SchermataIniziale), findsNothing);

    appRouter.router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
  });

  testWidgets('Accedi apre il login e indietro torna all\'inizio', (
    tester,
  ) async {
    // Preparazione: schermata iniziale. Azione: tocco su "Accedi".
    // Esito atteso (RF_ACC_3): si apre FormLogin; tornando indietro si rivede
    // la schermata iniziale.
    final AppRouter appRouter = await _apriSchermataIniziale(tester);

    await tester.tap(find.byKey(SchermataIniziale.chiaveAccedi));
    await tester.pumpAndSettle();

    expect(find.byType(FormLogin), findsOneWidget);
    expect(find.byType(SchermataIniziale), findsNothing);

    appRouter.router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
  });
}
