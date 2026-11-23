// Widget test di FormLega (KCK-249, RF_LEG_1): un test per ogni test frame
// di creazione (TF_LEG_01-05) e di modifica (TF_LEG_06-08) di
// docs/test/cp_UC_ACC_1_UC_LEG_1.md visibile nella GUI, piu' gli stati di
// caricamento, errore di rete e operazione non permessa (D13) richiesti dal
// ticket. Esiti attesi da UC_LEG_1, dai frame e da D13/D17, non dal codice.
// Control finto (control_finto.dart), nessun accesso al DB.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';
import 'package:kickly/features/leghe/presentation/form_lega.dart';

import 'control_finto.dart';

/// Lega fittizia gia' esistente, amministrata dal Giocatore (modifica).
const Lega _legaEsistente = Lega(
  id: '00000000-0000-4000-8000-000000000302',
  nome: 'Derby del Quartiere',
  tipologiaMatch: TipologiaMatch.setteVsSette,
  privacy: PrivacyLega.privata,
  codiceInvito: 'KCK78X9P',
);

/// Pulsante di invio del modulo.
final Finder _invia = find.byKey(const Key('form_lega_invia'));

/// Testo d'errore mostrato sotto il campo nome.
String? _erroreNome(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('form_lega_nome')))
    .decoration
    ?.errorText;

void main() {
  late GestioneLegaControlFinto control;

  setUp(() => control = GestioneLegaControlFinto());

  group('creazione (UC_LEG_1 passi 1-4)', () {
    // Preparazione: Giocatore autenticato nella sezione "Leghe"; nome non in
    // uso, 5vs5, Privata.
    // Esito atteso: la lega e' registrata e viene mostrata la dashboard
    // della lega con il codice d'invito generato (passo 4).
    testWidgets('tf_leg_01_privata_5vs5_mostra_la_dashboard_della_lega', (
      tester,
    ) async {
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Champions Giovedì',
      );
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(control.richieste.single, (
        idLega: null,
        nome: 'Champions Giovedì',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatoreFinto,
      ));
      expect(find.byType(FormLega), findsNothing);
      expect(find.byType(DashboardLega), findsOneWidget);
      expect(find.text('Champions Giovedì'), findsOneWidget);
      expect(find.text('Codice invito: KCK78X9P'), findsOneWidget);
    });

    // Preparazione: come TF_LEG_01 con privacy Pubblica (A1: interruttore
    // "Lega privata" spento).
    // Esito atteso: la lega e' registrata come pubblica e si apre la
    // dashboard.
    testWidgets('tf_leg_02_pubblica_invia_privacy_pubblica', (tester) async {
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Calcetto Aperto',
      );
      await tester.tap(find.byKey(const Key('form_lega_privacy')));
      await tester.pump();
      expect(find.text('Lega pubblica'), findsOneWidget);
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(control.richieste.single.privacy, PrivacyLega.pubblica);
      expect(find.byType(DashboardLega), findsOneWidget);
    });

    // Preparazione: Giocatore nella sezione "Leghe", tipologia 11vs11.
    // Esito atteso: la lega e' registrata con tipologia 11vs11.
    testWidgets('tf_leg_03_tipologia_11vs11_inviata_al_control', (
      tester,
    ) async {
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Lega a Undici',
      );
      await tester.tap(find.text('11 vs 11'));
      await tester.pump();
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(
        control.richieste.single.tipologiaMatch,
        TipologiaMatch.undiciVsUndici,
      );
      expect(find.byType(DashboardLega), findsOneWidget);
    });

    // Preparazione: esiste gia' una lega con lo stesso nome (il Control
    // lancia NomeLegaGiaInUsoException).
    // Esito atteso (E1): messaggio di errore, campo nome evidenziato, si
    // resta sul modulo (passo 2) con i dati inseriti.
    testWidgets('tf_leg_04_nome_gia_in_uso_evidenzia_il_nome_e_resta_sul_'
        'modulo', (tester) async {
      control.errore = NomeLegaGiaInUsoException();
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Champions Giovedì',
      );
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(_erroreNome(tester), 'Nome lega gia\' in uso');
      expect(find.byType(FormLega), findsOneWidget);
      expect(find.byType(DashboardLega), findsNothing);
      expect(find.text('Champions Giovedì'), findsOneWidget);
    });

    // Preparazione: modulo di creazione senza nome (il Control lancia
    // DatiLegaNonValidiException sul campo nome).
    // Esito atteso (E1): messaggio di errore, campo nome evidenziato, si
    // resta sul modulo.
    testWidgets('tf_leg_05_nome_vuoto_evidenzia_il_nome_e_resta_sul_modulo', (
      tester,
    ) async {
      control.errore = DatiLegaNonValidiException(
        DatiLegaNonValidiException.nome,
      );
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(control.richieste.single.nome, '');
      expect(_erroreNome(tester), 'Inserisci il nome della lega');
      expect(find.byType(FormLega), findsOneWidget);
      expect(find.byType(DashboardLega), findsNothing);
    });

    // Preparazione: Giocatore che scrive un nome di 35 caratteri.
    // Esito atteso (UI_LEG_2, limite dei PM): il campo accetta al massimo 30
    // caratteri e mostra il limite sotto il campo.
    testWidgets('il campo nome accetta al massimo 30 caratteri', (
      tester,
    ) async {
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(find.byKey(const Key('form_lega_nome')), 'B' * 35);
      await tester.pump();

      final TextField campo = tester.widget<TextField>(
        find.byKey(const Key('form_lega_nome')),
      );
      expect(campo.controller!.text, 'B' * 30);
      expect(
        find.text('Massimo 30 caratteri, modificabile in seguito.'),
        findsOneWidget,
      );
    });

    // Preparazione: il Control rifiuta la tipologia (caso non raggiungibile
    // dai pulsanti, ma la GUI deve mostrarlo).
    // Esito atteso (E1): messaggio sotto i formati, si resta sul modulo.
    testWidgets('tipologia non valida mostra l\'errore sotto i formati', (
      tester,
    ) async {
      control.errore = DatiLegaNonValidiException(
        DatiLegaNonValidiException.tipologiaMatch,
      );
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(find.byKey(const Key('form_lega_nome')), 'Lega');
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(find.text('Scegli una tipologia di match valida'), findsOneWidget);
      expect(find.byType(FormLega), findsOneWidget);
    });

    // Preparazione: il Control rifiuta la privacy.
    // Esito atteso (E1): messaggio sotto l'interruttore della privacy.
    testWidgets('privacy non valida mostra l\'errore sotto la privacy', (
      tester,
    ) async {
      control.errore = DatiLegaNonValidiException(
        DatiLegaNonValidiException.privacy,
      );
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(find.byKey(const Key('form_lega_nome')), 'Lega');
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(
        find.text('Scegli se la lega e\' Pubblica o Privata'),
        findsOneWidget,
      );
      expect(find.byType(FormLega), findsOneWidget);
    });

    // Preparazione: il Control non ha ancora risposto.
    // Esito atteso: pulsante disattivato con indicatore di caricamento, cosi'
    // il modulo non si invia due volte; poi la dashboard.
    testWidgets('durante l\'invio mostra il caricamento', (tester) async {
      control.attesa = Completer<void>();
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(find.byKey(const Key('form_lega_nome')), 'Lega');
      await tester.tap(_invia);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(_invia).onPressed, isNull);

      control.attesa!.complete();
      await tester.pumpAndSettle();
      expect(control.richieste, hasLength(1));
      expect(find.byType(DashboardLega), findsOneWidget);
    });

    // Preparazione: rete assente (il Control lancia AppException.network).
    // Esito atteso: messaggio specifico di rete, si resta sul modulo e si
    // puo' riprovare (exit condition on failure).
    testWidgets('errore di rete mostra il messaggio e resta sul modulo', (
      tester,
    ) async {
      control.errore = AppException.network();
      await apriSezioneLeghe(tester, control, '/leghe/nuova');

      await tester.enterText(find.byKey(const Key('form_lega_nome')), 'Lega');
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('form_lega_errore'))).data,
        AppException.network().message,
      );
      expect(find.byType(FormLega), findsOneWidget);
      expect(tester.widget<FilledButton>(_invia).onPressed, isNotNull);
    });
  });

  group('modifica (RF_LEG_1, FormLega)', () {
    // Preparazione: Amministratore che modifica nome, tipologia e privacy in
    // FormLega.
    // Esito atteso: i dettagli sono aggiornati e la dashboard mostra i nuovi
    // dati.
    testWidgets('tf_leg_06_amministratore_modifica_e_vede_i_nuovi_dati', (
      tester,
    ) async {
      await apriSezioneLeghe(
        tester,
        control,
        '/leghe/${_legaEsistente.id}/modifica',
        extra: _legaEsistente,
      );

      expect(find.text('Modifica lega'), findsOneWidget);
      expect(find.text('Derby del Quartiere'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Derby del Rione',
      );
      await tester.tap(find.text('8 vs 8'));
      await tester.tap(find.byKey(const Key('form_lega_privacy')));
      await tester.pump();
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(control.richieste.single, (
        idLega: _legaEsistente.id,
        nome: 'Derby del Rione',
        tipologiaMatch: TipologiaMatch.ottoVsOtto,
        privacy: PrivacyLega.pubblica,
        idGiocatore: idGiocatoreFinto,
      ));
      expect(find.byType(DashboardLega), findsOneWidget);
      expect(find.text('Derby del Rione'), findsOneWidget);
    });

    // Preparazione: Amministratore che rinomina la lega con il nome di
    // un'altra.
    // Esito atteso (E1, D17): messaggio di errore, nome evidenziato, si resta
    // su FormLega.
    testWidgets('tf_leg_08_nome_gia_in_uso_da_un_altra_lega_resta_su_form_'
        'lega', (tester) async {
      control.errore = NomeLegaGiaInUsoException();
      await apriSezioneLeghe(
        tester,
        control,
        '/leghe/${_legaEsistente.id}/modifica',
        extra: _legaEsistente,
      );

      await tester.enterText(
        find.byKey(const Key('form_lega_nome')),
        'Torneo Universitario',
      );
      await tester.tap(_invia);
      await tester.pumpAndSettle();

      expect(_erroreNome(tester), 'Nome lega gia\' in uso');
      expect(find.byType(FormLega), findsOneWidget);
      expect(find.byType(DashboardLega), findsNothing);
    });

    // Preparazione: richiesta di modifica da chi non e' amministratore (il
    // Control lancia OperazioneNonPermessaException, TF_LEG_07 lato GUI).
    // Esito atteso (D13): messaggio di errore e nessuna modifica; si resta
    // sul modulo. La parte "comando non visibile al membro" di TF_LEG_07 e'
    // della DashboardLega (KCK-216).
    testWidgets(
      'tf_leg_07_richiesta_diretta_di_un_membro_rifiutata_con_messaggio',
      (tester) async {
        control.errore = OperazioneNonPermessaException();
        await apriSezioneLeghe(
          tester,
          control,
          '/leghe/${_legaEsistente.id}/modifica',
          extra: _legaEsistente,
        );

        await tester.tap(_invia);
        await tester.pumpAndSettle();

        expect(
          find.text('Solo un amministratore puo\' modificare la lega'),
          findsOneWidget,
        );
        expect(find.byType(FormLega), findsOneWidget);
      },
    );

    // Preparazione: rotta di modifica aperta senza i dati della lega.
    // Esito atteso: non si mostra un modulo vuoto, si torna alla dashboard.
    testWidgets('modifica senza lega torna alla dashboard', (tester) async {
      await apriSezioneLeghe(
        tester,
        control,
        '/leghe/${_legaEsistente.id}/modifica',
      );

      expect(find.byType(FormLega), findsNothing);
      expect(find.byType(DashboardLega), findsOneWidget);
    });
  });
}
