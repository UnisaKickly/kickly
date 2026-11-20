// Widget test dell'app shell (KCK-194): tema, routing e blocco di accesso.
//
// Ogni test segue lo schema Arrange / Act / Assert e usa una sessione finta
// (SessioneFinta) al posto di AutenticazioneControl, come chiede il ticket.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/router/app_router.dart';

/// Sessione finta: lo stato si cambia dal test e avvisa il router come fara'
/// AutenticazioneControl dopo login e logout.
class SessioneFinta extends ChangeNotifier implements SessioneProvider {
  /// Crea la sessione finta con lo stato iniziale indicato (predefinito: non
  /// autenticata).
  SessioneFinta([this._autenticato = false]);

  bool _autenticato;

  @override
  bool get autenticato => _autenticato;

  /// Cambia lo stato della sessione e avvisa i listener (il router).
  set autenticato(bool valore) {
    _autenticato = valore;
    notifyListeners();
  }
}

void main() {
  testWidgets('utente non autenticato vede la schermata iniziale', (
    tester,
  ) async {
    await tester.pumpWidget(const KicklyApp());

    expect(find.text('Ciao da Kickly!'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
    expect(find.byType(SchermataIniziale), findsOneWidget);
  });

  testWidgets('utente autenticato vede la dashboard', (tester) async {
    await tester.pumpWidget(KicklyApp(sessioneProvider: SessioneFinta(true)));
    await tester.pumpAndSettle();

    expect(find.byType(Dashboard), findsOneWidget);
    expect(find.text('Ciao da Kickly!'), findsNothing);
  });

  testWidgets('utente non autenticato viene reindirizzato dalla dashboard', (
    tester,
  ) async {
    final AppRouter appRouter = AppRouter(
      sessioneProvider: const SessioneNonAutenticata(),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));

    appRouter.router.go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
    expect(find.byType(Dashboard), findsNothing);
  });

  // Verifica che login e registrazione restino accessibili agli utenti non
  // autenticati: naviga alle due rotte e controlla la Boundary mostrata.
  testWidgets(
    'utente non autenticato accede regolarmente a FormLogin e FormRegistrazione',
    (tester) async {
      final AppRouter appRouter = AppRouter(
        sessioneProvider: const SessioneNonAutenticata(),
      );
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );

      appRouter.router.go('/login');
      await tester.pumpAndSettle();
      expect(find.byType(FormLogin), findsOneWidget);

      appRouter.router.go('/registrazione');
      await tester.pumpAndSettle();
      expect(find.byType(FormRegistrazione), findsOneWidget);
    },
  );

  // Verifica che il router ascolti la sessione: dal form di login, appena la
  // sessione diventa autenticata, passa da solo alla dashboard; dopo il logout
  // torna alla schermata iniziale.
  testWidgets('login e logout cambiano schermata senza navigare a mano', (
    tester,
  ) async {
    final SessioneFinta sessione = SessioneFinta();
    final AppRouter appRouter = AppRouter(sessioneProvider: sessione);
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));
    appRouter.router.go('/login');
    await tester.pumpAndSettle();
    expect(find.byType(FormLogin), findsOneWidget);

    sessione.autenticato = true;
    await tester.pumpAndSettle();
    expect(find.byType(Dashboard), findsOneWidget);

    sessione.autenticato = false;
    await tester.pumpAndSettle();
    expect(find.byType(SchermataIniziale), findsOneWidget);
    expect(find.byType(Dashboard), findsNothing);
  });
}
