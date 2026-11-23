// Test di GestioneLegaControl (RF_LEG_1, KCK-242): un test per ogni test
// frame di creazione lega (F6, TF_LEG_01-05) di
// docs/test/cp_UC_ACC_1_UC_LEG_1.md, piu' due test senza id per tipologia e
// privacy non valide (citate dal ticket, assenti nel cp).
// Esiti attesi presi dai frame, da UC_LEG_1 e da D21, non dal codice.
// Repository in memoria, nessun accesso al DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  // Dati fittizi: Giocatore autenticato nella sezione "Leghe".
  const idGiocatore = '00000000-0000-4000-8000-000000000201';
  final adesso = DateTime.utc(2026, 11, 23, 10);

  late InMemoryLegaRepository repository;
  late GestioneLegaControl control;

  setUp(() {
    repository = InMemoryLegaRepository();
    control = GestioneLegaControl(
      legaRepository: repository,
      orologio: () => adesso,
    );
  });

  /// Verifica che [idGiocatore] sia membro e unico amministratore della lega.
  ///
  /// LegaRepository non espone gli amministratori: l'unico amministratore non
  /// puo' essere rimosso (D17), quindi il rifiuto della rimozione prova che
  /// il creatore e' amministratore.
  Future<void> verificaAmministratore(Lega lega) async {
    final leghe = await repository.findByGiocatore(idGiocatore);
    expect(leghe.map((l) => l.id), contains(lega.id));
    await expectLater(
      repository.rimuoviMembro(lega.id, idGiocatore),
      throwsA(isA<AppException>().having((e) => e.code, 'code', '23514')),
    );
  }

  group('F6 Creazione lega (UC_LEG_1 passi 1-4)', () {
    // Preparazione: Giocatore autenticato nella sezione "Leghe", nessuna lega.
    // Esito atteso: la lega e' registrata, l'utente ne diventa Amministratore,
    // viene generato un codice d'invito univoco (la GUI mostra la dashboard).
    test('tf_leg_01_nomeLibero5vs5Privata_creaLegaConAdminECodice', () async {
      final lega = await control.creaLega(
        nome: 'Champions Giovedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );

      expect(lega.id, isNotEmpty);
      expect(await repository.findById(lega.id), isNotNull);
      expect(lega.nome, 'Champions Giovedi');
      expect(lega.tipologiaMatch, TipologiaMatch.cinqueVsCinque);
      expect(lega.privacy, PrivacyLega.privata);
      expect(lega.codiceInvito, isNotNull);
      expect(lega.codiceInvito, isNotEmpty);
      expect(lega.scadenzaCodiceInvito, isNotNull);
      expect(lega.scadenzaCodiceInvito!.isAfter(adesso), isTrue);
      expect(
        (await repository.findByCodiceInvito(lega.codiceInvito!))?.id,
        lega.id,
      );
      await verificaAmministratore(lega);
      // Una lega privata non compare nella ricerca globale.
      expect(await repository.findPubbliche(), isEmpty);
    });

    // Preparazione: come TF_LEG_01, privacy Pubblica.
    // Esito atteso: come TF_LEG_01; inoltre la lega e' visibile nella ricerca
    // globale (A1).
    test('tf_leg_02_nomeLibero5vs5Pubblica_legaVisibileInRicerca', () async {
      final lega = await control.creaLega(
        nome: 'Calcetto del Lunedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.pubblica,
        idGiocatore: idGiocatore,
      );

      expect(lega.privacy, PrivacyLega.pubblica);
      expect(lega.codiceInvito, isNotNull);
      await verificaAmministratore(lega);
      final pubbliche = await repository.findPubbliche();
      expect(pubbliche.map((l) => l.id), contains(lega.id));
    });

    // Preparazione: Giocatore autenticato, tipologia 11vs11 (limite superiore).
    // Esito atteso: lega registrata con tipologia 11vs11, l'utente ne diventa
    // Amministratore.
    test('tf_leg_03_tipologia11vs11_creaLega', () async {
      final lega = await control.creaLega(
        nome: 'Campionato a 11',
        tipologiaMatch: TipologiaMatch.undiciVsUndici,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );

      expect(lega.tipologiaMatch, TipologiaMatch.undiciVsUndici);
      await verificaAmministratore(lega);
    });

    // Preparazione: esiste gia' una lega con lo stesso nome (con maiuscole e
    // spazi diversi: per D21 e' lo stesso nome).
    // Esito atteso: messaggio di errore con il nome da correggere, si resta al
    // passo 2 e la lega non viene creata (E1).
    test('tf_leg_04_nomeGiaInUso_rifiuta', () async {
      await control.creaLega(
        nome: 'Champions Giovedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: '00000000-0000-4000-8000-000000000202',
      );

      await expectLater(
        control.creaLega(
          nome: '  champions giovedi ',
          tipologiaMatch: TipologiaMatch.setteVsSette,
          privacy: PrivacyLega.pubblica,
          idGiocatore: idGiocatore,
        ),
        throwsA(
          isA<NomeLegaGiaInUsoException>()
              .having((e) => e.message, 'message', isNotEmpty)
              .having((e) => e.campo, 'campo', DatiLegaNonValidiException.nome),
        ),
      );
      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });

    // Preparazione: modulo di creazione senza nome (solo spazi).
    // Esito atteso: messaggio di errore con il nome evidenziato, si resta al
    // passo 2 e la lega non viene creata (E1).
    test('tf_leg_05_nomeVuoto_rifiuta', () async {
      await expectLater(
        control.creaLega(
          nome: '   ',
          tipologiaMatch: TipologiaMatch.cinqueVsCinque,
          privacy: PrivacyLega.privata,
          idGiocatore: idGiocatore,
        ),
        throwsA(
          isA<DatiLegaNonValidiException>()
              .having((e) => e.campo, 'campo', DatiLegaNonValidiException.nome)
              .having((e) => e.message, 'message', isNotEmpty),
        ),
      );
      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });

    // Senza id TF: il ticket cita "tipologia non valida" ma il cp non ha il
    // frame. Esito atteso da UC_LEG_1 E1 (dati non validi): errore sul campo
    // tipologia e lega non creata.
    test('tipologia non valida: rifiuta con errore sul campo', () async {
      await expectLater(
        control.creaLega(
          nome: 'Lega a 4',
          tipologiaMatch: '4v4',
          privacy: PrivacyLega.privata,
          idGiocatore: idGiocatore,
        ),
        throwsA(
          isA<DatiLegaNonValidiException>().having(
            (e) => e.campo,
            'campo',
            DatiLegaNonValidiException.tipologiaMatch,
          ),
        ),
      );
      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });

    // Senza id TF: privacy diversa da Pubblica/Privata. Esito atteso da
    // UC_LEG_1 E1 (dati non validi): errore sul campo privacy e lega non
    // creata.
    test('privacy non valida: rifiuta con errore sul campo', () async {
      await expectLater(
        control.creaLega(
          nome: 'Lega segreta',
          tipologiaMatch: TipologiaMatch.cinqueVsCinque,
          privacy: 'nascosta',
          idGiocatore: idGiocatore,
        ),
        throwsA(
          isA<DatiLegaNonValidiException>().having(
            (e) => e.campo,
            'campo',
            DatiLegaNonValidiException.privacy,
          ),
        ),
      );
      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });
  });
}
