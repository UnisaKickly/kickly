// Widget test di VistaLeghe (KCK-249, UI_LEG_1): stati di caricamento,
// errore di rete, lista vuota e lista con il ruolo, e ingresso a "Crea lega"
// (UC_LEG_1 passo 1). Il ticket non associa test frame a questa schermata.
// Control finto (control_finto.dart), nessun accesso al DB.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/leghe/domain/lega.dart';
import 'package:kickly/features/leghe/presentation/form_lega.dart';

import 'control_finto.dart';

const Lega _legaAdmin = Lega(
  id: '00000000-0000-4000-8000-000000000311',
  nome: 'Derby del Quartiere',
  tipologiaMatch: TipologiaMatch.setteVsSette,
  privacy: PrivacyLega.privata,
);

const Lega _legaMembro = Lega(
  id: '00000000-0000-4000-8000-000000000312',
  nome: 'Torneo Universitario',
  tipologiaMatch: TipologiaMatch.cinqueVsCinque,
  privacy: PrivacyLega.pubblica,
);

void main() {
  late GestioneLegaControlFinto control;

  setUp(() => control = GestioneLegaControlFinto());

  // Preparazione: Giocatore iscritto a due leghe, amministratore di una.
  // Esito atteso: entrambe le leghe con il badge del ruolo (UI_LEG_1).
  testWidgets('mostra le leghe del giocatore con il ruolo', (tester) async {
    control.leghe = [
      (lega: _legaAdmin, amministratore: true),
      (lega: _legaMembro, amministratore: false),
    ];
    await apriSezioneLeghe(tester, control, '/leghe');

    expect(find.text('Derby del Quartiere'), findsOneWidget);
    expect(find.text('Calcio a 7 · Privata'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Torneo Universitario'), findsOneWidget);
    expect(find.text('MEMBRO'), findsOneWidget);
  });

  // Preparazione: il Control non ha ancora risposto.
  // Esito atteso: indicatore di caricamento al posto dell'elenco.
  testWidgets('mostra il caricamento prima dell\'elenco', (tester) async {
    control.attesaElenco = Completer<void>();
    control.leghe = [(lega: _legaAdmin, amministratore: true)];
    await apriSezioneLeghe(tester, control, '/leghe', attendi: false);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Derby del Quartiere'), findsNothing);

    control.attesaElenco!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Derby del Quartiere'), findsOneWidget);
  });

  // Preparazione: rete assente.
  // Esito atteso: messaggio specifico di rete e "Riprova", che ricarica.
  testWidgets('errore di rete mostra il messaggio e permette di riprovare', (
    tester,
  ) async {
    control.erroreElenco = AppException.network();
    await apriSezioneLeghe(tester, control, '/leghe');

    expect(
      tester.widget<Text>(find.byKey(const Key('vista_leghe_errore'))).data,
      AppException.network().message,
    );

    control.erroreElenco = null;
    control.leghe = [(lega: _legaMembro, amministratore: false)];
    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();

    expect(control.chiamateElenco, 2);
    expect(find.text('Torneo Universitario'), findsOneWidget);
  });

  // Preparazione: Giocatore non iscritto a nessuna lega.
  // Esito atteso: messaggio che invita a creare una lega o a unirsi.
  testWidgets('lista vuota mostra il messaggio', (tester) async {
    await apriSezioneLeghe(tester, control, '/leghe');

    expect(
      find.textContaining('Non sei ancora iscritto a nessuna lega'),
      findsOneWidget,
    );
  });

  // Preparazione: Giocatore nella sezione "Leghe".
  // Esito atteso (passi 1-2): "Crea lega" mostra il modulo di creazione.
  testWidgets('crea lega apre il modulo di creazione', (tester) async {
    await apriSezioneLeghe(tester, control, '/leghe');

    await tester.tap(find.byKey(const Key('vista_leghe_crea')));
    await tester.pumpAndSettle();

    expect(find.byType(FormLega), findsOneWidget);
    expect(find.text('Crea lega e genera invito'), findsOneWidget);
  });

  // Preparazione: Giocatore iscritto a una lega.
  // Esito atteso: toccando la lega si apre la sua dashboard.
  testWidgets('toccare una lega apre la sua dashboard', (tester) async {
    control.leghe = [(lega: _legaAdmin, amministratore: true)];
    await apriSezioneLeghe(tester, control, '/leghe');

    await tester.tap(find.byKey(Key('vista_leghe_lega_${_legaAdmin.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(DashboardLega), findsOneWidget);
    expect(find.text('Derby del Quartiere'), findsOneWidget);
  });

  // Preparazione: utente senza sessione che apre la sezione Leghe.
  // Esito atteso (entry condition di UC_LEG_1): torna alla schermata
  // iniziale, la VistaLeghe non si apre.
  testWidgets('senza sessione la sezione leghe non si apre', (tester) async {
    final AppRouter appRouter = AppRouter(
      sessioneProvider: const SessioneNonAutenticata(),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));

    appRouter.router.go('/leghe/nuova');
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
    expect(find.byType(FormLega), findsNothing);
  });
}
