// Control finto di GestioneLegaControl e apertura dell'app per i widget test
// delle schermate della lega (KCK-249). Nessun repository e nessun accesso
// al DB: il test decide cosa restituisce o lancia ogni metodo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/provider/gestione_lega_provider.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

/// Id fittizio del Giocatore autenticato.
const String idGiocatoreFinto = '00000000-0000-4000-8000-000000000201';

/// Richiesta ricevuta dal Control finto, per controllare cosa invia la GUI.
typedef RichiestaLega = ({
  String? idLega,
  String nome,
  String tipologiaMatch,
  String privacy,
  String idGiocatore,
});

/// Sessione sempre autenticata, per entrare nella sezione Leghe.
class SessioneAutenticataFinta extends ChangeNotifier
    implements SessioneProvider {
  @override
  bool get autenticato => true;
}

/// GestioneLegaControl finto: registra le richieste e risponde come dice il
/// test.
class GestioneLegaControlFinto implements GestioneLegaControl {
  /// Richieste di creazione e modifica ricevute, nell'ordine.
  final List<RichiestaLega> richieste = [];

  /// Errore da lanciare alla prossima creazione o modifica; null = successo.
  Object? errore;

  /// Se impostato, creazione e modifica aspettano che il test lo completi.
  Completer<void>? attesa;

  /// Risposta di visualizzaLeghe, o errore da lanciare.
  List<({Lega lega, bool amministratore})> leghe = [];
  Object? erroreElenco;

  /// Se impostato, visualizzaLeghe aspetta che il test lo completi.
  Completer<void>? attesaElenco;

  /// Numero di chiamate a visualizzaLeghe.
  int chiamateElenco = 0;

  @override
  Future<Lega> creaLega({
    required String nome,
    required String tipologiaMatch,
    required String privacy,
    required String idGiocatore,
  }) async {
    richieste.add((
      idLega: null,
      nome: nome,
      tipologiaMatch: tipologiaMatch,
      privacy: privacy,
      idGiocatore: idGiocatore,
    ));
    await attesa?.future;
    if (errore != null) throw errore!;
    return Lega(
      id: '00000000-0000-4000-8000-000000000301',
      nome: nome.trim(),
      tipologiaMatch: tipologiaMatch,
      privacy: privacy,
      codiceInvito: 'KCK78X9P',
      scadenzaCodiceInvito: DateTime.utc(2026, 11, 30),
    );
  }

  @override
  Future<Lega> modificaDettagliLega({
    required String idLega,
    required String nome,
    required String tipologiaMatch,
    required String privacy,
    required String idGiocatore,
  }) async {
    richieste.add((
      idLega: idLega,
      nome: nome,
      tipologiaMatch: tipologiaMatch,
      privacy: privacy,
      idGiocatore: idGiocatore,
    ));
    await attesa?.future;
    if (errore != null) throw errore!;
    return Lega(
      id: idLega,
      nome: nome.trim(),
      tipologiaMatch: tipologiaMatch,
      privacy: privacy,
      codiceInvito: 'KCK78X9P',
    );
  }

  /// Restituisce il codice d'invito fittizio richiesto dai widget test.
  ///
  /// Fornisce la risposta minima necessaria ai test senza creare repository
  /// o accedere al database.
  @override
  Future<String> generaCodiceInvito({
    required String idLega,
    required String idGiocatore,
  }) async {
    return 'KCK78X9P';
  }

  /// Restituisce il link d'invito fittizio richiesto dai widget test.
  ///
  /// Mantiene separata la risposta del fake dall'orchestrazione reale del
  /// codice invito e non introduce logica o dipendenze esterne.
  @override
  Future<String> generaLinkInvito({
    required String idLega,
    required String idGiocatore,
  }) async {
    return 'https://unisakickly.github.io/kickly/#/lega/invito/KCK78X9P';
  }

  @override
  Future<List<({Lega lega, bool amministratore})>> visualizzaLeghe(
    String idGiocatore,
  ) async {
    chiamateElenco++;
    await attesaElenco?.future;
    if (erroreElenco != null) throw erroreElenco!;
    return leghe;
  }

  // Gestione membri (RF_LEG_3, KCK-222): le schermate di KCK-249 non la
  // usano; le risposte vere arriveranno con la GUI di KCK-228.
  @override
  Future<List<({String idGiocatore, bool amministratore})>> visualizzaMembri({
    required String idLega,
    required String idGiocatore,
  }) async => [];

  @override
  Future<void> promuoviAdAmministratore({
    required String idLega,
    required String idMembro,
    required String idGiocatore,
  }) async {}

  @override
  Future<void> rimuoviMembro({
    required String idLega,
    required String idMembro,
    required String idGiocatore,
  }) async {}
}

/// Avvia l'app autenticata sulla rotta [percorso] con il Control finto e
/// restituisce il router.
Future<AppRouter> apriSezioneLeghe(
  WidgetTester tester,
  GestioneLegaControlFinto control,
  String percorso, {
  Object? extra,
  bool attendi = true,
}) async {
  // Schermo alto come un telefono, cosi' tutto il modulo e' visibile.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final AppRouter appRouter = AppRouter(
    sessioneProvider: SessioneAutenticataFinta(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gestioneLegaControlProvider.overrideWithValue(control),
        idGiocatoreAutenticatoProvider.overrideWithValue(
          () => idGiocatoreFinto,
        ),
      ],
      child: MaterialApp.router(routerConfig: appRouter.router),
    ),
  );
  appRouter.router.go(percorso, extra: extra);
  // Con [attendi] false si fa un solo frame, per vedere il caricamento.
  if (attendi) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return appRouter;
}
