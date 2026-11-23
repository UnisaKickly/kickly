// Test di GestioneLegaControl (RF_LEG_1, KCK-242): un test per ogni test
// frame di creazione (F6, TF_LEG_01-05) e di modifica (F7, TF_LEG_06-08) di
// docs/test/cp_UC_ACC_1_UC_LEG_1.md, piu' test senza id per tipologia e
// privacy non valide (citate dal ticket, assenti nel cp), per il codice
// d'invito gia' usato e per la rinomina con il proprio nome.
// Esiti attesi presi dai frame, da UC_LEG_1 e da D21, non dal codice.
// Repository in memoria, nessun accesso al DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

/// Repository che rifiuta la prima creazione come se il codice d'invito
/// fosse gia' usato da una lega che la ricerca non vede (es. lega privata
/// altrui nascosta dalla RLS di KCK-226).
class _RepositoryCodiceGiaUsato extends InMemoryLegaRepository {
  /// Codici d'invito ricevuti a ogni tentativo di creazione.
  final List<String?> codiciProvati = [];

  @override
  Future<Lega> createLega(Lega lega, String adminGiocatoreId) async {
    codiciProvati.add(lega.codiceInvito);
    if (codiciProvati.length == 1) {
      throw AppException.database(
        message: 'Esiste già un elemento con questi dati.',
        code: '23505',
      );
    }
    return super.createLega(lega, adminGiocatoreId);
  }
}

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

  group('Codice d\'invito (UC_LEG_1 passo 4, D29)', () {
    // Senza id TF (richiesta dei PM su KCK-242): il primo codice generato e'
    // gia' usato da un'altra lega che la ricerca non vede. Esito atteso: il
    // Control genera un altro codice e crea comunque la lega.
    test('codice gia\' usato: ne genera un altro e crea la lega', () async {
      final repositoryCodice = _RepositoryCodiceGiaUsato();
      final controlCodice = GestioneLegaControl(
        legaRepository: repositoryCodice,
        orologio: () => adesso,
      );

      final lega = await controlCodice.creaLega(
        nome: 'Lega del Martedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );

      expect(repositoryCodice.codiciProvati, hasLength(2));
      expect(
        repositoryCodice.codiciProvati[1],
        isNot(repositoryCodice.codiciProvati[0]),
      );
      expect(lega.codiceInvito, repositoryCodice.codiciProvati[1]);
      expect(await repositoryCodice.findById(lega.id), isNotNull);
    });

    // Formato e durata decisi dai PM (D29): 8 caratteri tra lettere
    // maiuscole e cifre senza 0/O e 1/I, scadenza a 7 giorni.
    test('formato e scadenza del codice come in D29', () async {
      final lega = await control.creaLega(
        nome: 'Lega del Mercoledi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );

      expect(lega.codiceInvito, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
      expect(lega.scadenzaCodiceInvito, adesso.add(const Duration(days: 7)));
    });
  });

  group('F7 Modifica dei dettagli della lega (RF_LEG_1)', () {
    const idMembro = '00000000-0000-4000-8000-000000000203';
    late Lega legaEsistente;

    setUp(() async {
      legaEsistente = await control.creaLega(
        nome: 'Champions Giovedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );
      await repository.aggiungiMembro(legaEsistente.id, idMembro);
    });

    // Preparazione: amministratore che modifica nome, tipologia e privacy in
    // FormLega. Esito atteso: i dettagli della lega sono aggiornati (la GUI
    // mostra i nuovi dati nella dashboard).
    test('tf_leg_06_adminDatiValidi_aggiornaLega', () async {
      final modificata = await control.modificaDettagliLega(
        idLega: legaEsistente.id,
        nome: 'Champions Venerdi',
        tipologiaMatch: TipologiaMatch.setteVsSette,
        privacy: PrivacyLega.pubblica,
        idGiocatore: idGiocatore,
      );

      expect(modificata.nome, 'Champions Venerdi');
      expect(modificata.tipologiaMatch, TipologiaMatch.setteVsSette);
      expect(modificata.privacy, PrivacyLega.pubblica);
      final salvata = await repository.findById(legaEsistente.id);
      expect(salvata?.nome, 'Champions Venerdi');
      expect(salvata?.tipologiaMatch, TipologiaMatch.setteVsSette);
      expect(salvata?.privacy, PrivacyLega.pubblica);
      // Il codice d'invito non cambia con la modifica dei dettagli.
      expect(salvata?.codiceInvito, legaEsistente.codiceInvito);
    });

    // Preparazione: membro ordinario della lega che invia una modifica.
    // Esito atteso: richiesta rifiutata con un messaggio di errore e lega
    // invariata (D13).
    test('tf_leg_07_membroNonAdmin_rifiuta', () async {
      await expectLater(
        control.modificaDettagliLega(
          idLega: legaEsistente.id,
          nome: 'Lega del Membro',
          tipologiaMatch: TipologiaMatch.undiciVsUndici,
          privacy: PrivacyLega.pubblica,
          idGiocatore: idMembro,
        ),
        throwsA(
          isA<OperazioneNonPermessaException>().having(
            (e) => e.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
      final salvata = await repository.findById(legaEsistente.id);
      expect(salvata?.nome, 'Champions Giovedi');
      expect(salvata?.tipologiaMatch, TipologiaMatch.cinqueVsCinque);
      expect(salvata?.privacy, PrivacyLega.privata);
    });

    // Preparazione: amministratore che rinomina la lega con il nome di
    // un'altra lega (maiuscole e spazi diversi, D21). Esito atteso: come E1,
    // errore sul nome, si resta su FormLega e la lega resta invariata (D17).
    test('tf_leg_08_nomeDiAltraLega_rifiuta', () async {
      await control.creaLega(
        nome: 'Lega del Sabato',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.pubblica,
        idGiocatore: '00000000-0000-4000-8000-000000000204',
      );

      await expectLater(
        control.modificaDettagliLega(
          idLega: legaEsistente.id,
          nome: ' lega del sabato ',
          tipologiaMatch: TipologiaMatch.cinqueVsCinque,
          privacy: PrivacyLega.privata,
          idGiocatore: idGiocatore,
        ),
        throwsA(
          isA<NomeLegaGiaInUsoException>().having(
            (e) => e.campo,
            'campo',
            DatiLegaNonValidiException.nome,
          ),
        ),
      );
      final salvata = await repository.findById(legaEsistente.id);
      expect(salvata?.nome, 'Champions Giovedi');
    });

    // Senza id TF (richiesta dei PM): rinominare la lega con il proprio nome,
    // cambiando solo maiuscole o spazi, e' permesso.
    test('proprio nome con maiuscole diverse: modifica permessa', () async {
      final modificata = await control.modificaDettagliLega(
        idLega: legaEsistente.id,
        nome: ' CHAMPIONS giovedi ',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      );

      expect(modificata.nome, 'CHAMPIONS giovedi');
      expect(
        (await repository.findById(legaEsistente.id))?.nome,
        'CHAMPIONS giovedi',
      );
    });
  });
}
