import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/router/app_router.dart';

void main() {
  testWidgets('utente non autenticato vede la schermata iniziale', (
    tester,
  ) async {
    await tester.pumpWidget(const KicklyApp());

    expect(find.text('Ciao da Kickly!'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });

  testWidgets('utente autenticato vede la dashboard', (tester) async {
    await tester.pumpWidget(
      const KicklyApp(sessioneProvider: SessioneProvider(autenticato: true)),
    );

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Ciao da Kickly!'), findsNothing);
  });

  testWidgets('utente non autenticato viene reindirizzato dalla dashboard', (
    tester,
  ) async {
    final AppRouter appRouter = AppRouter(
      sessioneProvider: const SessioneProvider(),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));

    appRouter.router.go('/dashboard');
    await tester.pumpAndSettle();

    expect(find.text('Ciao da Kickly!'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  // Verifica l'avvio senza autenticazione: prepara SessioneProvider non autenticato,
  // monta KicklyApp e controlla che venga mostrata SchermataIniziale.
  testWidgets('avvio con utente non autenticato mostra SchermataIniziale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const KicklyApp(sessioneProvider: SessioneProvider(autenticato: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
  });

  // Verifica l'avvio con autenticazione: prepara SessioneProvider autenticato,
  // monta KicklyApp e controlla che venga mostrata Dashboard.
  testWidgets('avvio con utente autenticato mostra Dashboard', (tester) async {
    await tester.pumpWidget(
      const KicklyApp(sessioneProvider: SessioneProvider(autenticato: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dashboard), findsOneWidget);
  });

  // Verifica il blocco della dashboard: apre direttamente la route protetta
  // con SessioneProvider non autenticato e attende il reindirizzamento iniziale.
  testWidgets(
    'accesso diretto a /dashboard senza autenticazione reindirizza a SchermataIniziale',
    (tester) async {
      final appRouter = AppRouter(
        sessioneProvider: const SessioneProvider(autenticato: false),
      );
      appRouter.router.go('/dashboard');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: appRouter.router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SchermataIniziale), findsOneWidget);
    },
  );

  // Verifica che login e registrazione restino accessibili agli utenti non autenticati:
  // prepara due router separati, naviga alle rispettive route e controlla il boundary mostrato.
  testWidgets(
    'utente non autenticato accede regolarmente a FormLogin e FormRegistrazione',
    (tester) async {
      final loginRouter = AppRouter(
        sessioneProvider: const SessioneProvider(autenticato: false),
      );
      loginRouter.router.go('/login');
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: loginRouter.router),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FormLogin), findsOneWidget);

      final registrazioneRouter = AppRouter(
        sessioneProvider: const SessioneProvider(autenticato: false),
      );
      registrazioneRouter.router.go('/registrazione');
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: registrazioneRouter.router),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FormRegistrazione), findsOneWidget);
    },
  );
}
