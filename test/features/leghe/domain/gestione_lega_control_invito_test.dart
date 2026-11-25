// Test di Generazione e condivisione dell'invito (RF_LEG_2, KCK-256):
// copertura della prima parte di F8 con TF_LEG_09, TF_LEG_10 e TF_LEG_11.
// Le preparazioni e gli esiti attesi derivano dai frame e da UC_LEG_1.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

/// Repository che simula una collisione solo al primo aggiornamento del codice.
///
/// I tentativi successivi vengono salvati nel repository in memoria senza
/// effettuare chiamate a Supabase.
class _RepositoryCollisioneInvitoUnaVolta extends InMemoryLegaRepository {
  /// Codici ricevuti dalla rigenerazione di [GestioneLegaControl].
  final List<String?> codiciProvati = [];

  /// Indica se gli aggiornamenti successivi devono simulare la collisione.
  bool collisioniAttive = false;

  @override
  Future<Lega> updateLega(Lega lega) async {
    if (!collisioniAttive) {
      return super.updateLega(lega);
    }
    codiciProvati.add(lega.codiceInvito);
    if (codiciProvati.length == 1) {
      throw AppException.database(
        message: 'Esiste gia\' un elemento con questi dati.',
        code: '23505',
      );
    }
    return super.updateLega(lega);
  }
}

/// Repository che simula una collisione a ogni aggiornamento del codice.
///
/// Permette di verificare il limite massimo di retry previsto da D29.
class _RepositoryCollisioneInvitoSempre extends InMemoryLegaRepository {
  /// Numero di tentativi ricevuti dal Control.
  int tentativi = 0;

  @override
  Future<Lega> updateLega(Lega lega) async {
    tentativi++;
    throw AppException.database(
      message: 'Esiste gia\' un elemento con questi dati.',
      code: '23505',
    );
  }
}

void main() {
  const idAmministratore = '00000000-0000-4000-8000-000000000201';
  const idMembro = '00000000-0000-4000-8000-000000000202';
  final adesso = DateTime.utc(2026, 11, 24, 10);

  late InMemoryLegaRepository repository;
  late GestioneLegaControl control;

  setUp(() {
    repository = InMemoryLegaRepository();
    control = GestioneLegaControl(
      legaRepository: repository,
      orologio: () => adesso,
    );
  });

  /// Prepara una lega appena creata amministrata da [idAmministratore].
  ///
  /// Il valore restituito rappresenta lo stato persistito dalla creazione e
  /// viene usato dai test di condivisione dell'invito.
  Future<Lega> creaLega() => control.creaLega(
    nome: 'Lega Inviti',
    tipologiaMatch: TipologiaMatch.cinqueVsCinque,
    privacy: PrivacyLega.privata,
    idGiocatore: idAmministratore,
  );

  /// Gruppo della generazione e condivisione riservata agli amministratori.
  ///
  /// Gli esiti attesi provengono da TF_LEG_09-TF_LEG_11 e da D29.
  group('F8 Generazione e condivisione dell\'invito', () {
    /// Verifica TF_LEG_09: Preparazione: amministratore seleziona
    /// "Condividi Invito" su una lega appena creata. Esito atteso: viene
    /// inviato un codice univoco di 8 caratteri con scadenza a 7 giorni da
    /// adesso, e lo stato persistito resta consistente.
    test('tf_leg_09_adminGeneraCodiceInvito_restituisceCodiceDiOttoCaratteriEScadzaDopoSetteGiorni', () async {
      final lega = await creaLega();

      final codice = await control.generaCodiceInvito(
        idLega: lega.id,
        idGiocatore: idAmministratore,
      );

      expect(codice, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
      expect(codice, lega.codiceInvito);
      expect(
        lega.scadenzaCodiceInvito,
        adesso.add(GestioneLegaControl.durataCodiceInvito),
      );
      expect((await repository.findByCodiceInvito(codice))?.id, lega.id);
    });

    /// Verifica TF_LEG_10: Preparazione: amministratore con una lega esistente
    /// genera il link d'invito. Esito atteso: il link usa esattamente il formato
    /// canonico richiesto dal caso d'uso e termina con il codice valido.
    test('tf_leg_10_adminGeneraLinkInvito_usaFormatoCanonico', () async {
      final lega = await creaLega();

      final link = await control.generaLinkInvito(
        idLega: lega.id,
        idGiocatore: idAmministratore,
      );

      expect(
        link,
        'https://unisakickly.github.io/kickly/#/lega/invito/${lega.codiceInvito}',
      );
    });

    /// Verifica TF_LEG_11: Preparazione: membro ordinario tenta direttamente
    /// di generare o condividere l'invito. Esito atteso: la richiesta viene
    /// rifiutata con CondivisioneInvitoNonPermessaException e la lega resta
    /// priva di modifiche al codice.
    test('tf_leg_11_membroNonAdmin_rifiutaGenerazioneECondivisione', () async {
      final lega = await creaLega();
      await repository.aggiungiMembro(lega.id, idMembro);

      await expectLater(
        control.generaCodiceInvito(idLega: lega.id, idGiocatore: idMembro),
        throwsA(isA<CondivisioneInvitoNonPermessaException>()),
      );
      await expectLater(
        control.generaLinkInvito(idLega: lega.id, idGiocatore: idMembro),
        throwsA(isA<CondivisioneInvitoNonPermessaException>()),
      );

      final salvata = await repository.findById(lega.id);
      expect(salvata?.codiceInvito, lega.codiceInvito);
      expect(salvata?.scadenzaCodiceInvito, lega.scadenzaCodiceInvito);
    });

    /// Verifica il caso aggiuntivo D29: Preparazione: il codice della lega
    /// esistente risulta scaduto. Esito atteso: il sistema genera
    /// automaticamente un nuovo codice e una nuova scadenza a 7 giorni.
    test('d29_codiceInvitoScaduto_rigeneraCodiceEScadenza', () async {
      final lega = await creaLega();
      final codiceScaduto = lega.codiceInvito!;
      final legaScaduta = Lega(
        id: lega.id,
        nome: lega.nome,
        tipologiaMatch: lega.tipologiaMatch,
        privacy: lega.privacy,
        codiceInvito: codiceScaduto,
        scadenzaCodiceInvito: adesso.subtract(const Duration(seconds: 1)),
      );
      await repository.updateLega(legaScaduta);

      final nuovoCodice = await control.generaCodiceInvito(
        idLega: lega.id,
        idGiocatore: idAmministratore,
      );

      expect(nuovoCodice, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
      expect(nuovoCodice, isNot(codiceScaduto));
      final salvata = await repository.findById(lega.id);
      expect(salvata?.codiceInvito, nuovoCodice);
      expect(
        salvata?.scadenzaCodiceInvito,
        adesso.add(GestioneLegaControl.durataCodiceInvito),
      );
    });

    /// Verifica il retry D29 dopo una collisione 23505 al primo
    /// aggiornamento del codice scaduto.
    test(
      'd29_collisione23505_rigeneraSecondoCodiceECompletaAggiornamento',
      () async {
        final repositoryCollisione = _RepositoryCollisioneInvitoUnaVolta();
        final controlCollisione = GestioneLegaControl(
          legaRepository: repositoryCollisione,
          orologio: () => adesso,
        );
        final legaScaduta = await repositoryCollisione.createLega(
          Lega(
            id: '',
            nome: 'Lega Collisione Singola',
            tipologiaMatch: TipologiaMatch.cinqueVsCinque,
            privacy: PrivacyLega.privata,
            codiceInvito: 'OLD12345',
            scadenzaCodiceInvito: adesso.subtract(const Duration(seconds: 1)),
          ),
          idAmministratore,
        );
        repositoryCollisione.collisioniAttive = true;

        final nuovoCodice = await controlCollisione.generaCodiceInvito(
          idLega: legaScaduta.id,
          idGiocatore: idAmministratore,
        );

        expect(repositoryCollisione.codiciProvati, hasLength(2));
        expect(
          repositoryCollisione.codiciProvati.first,
          isNot(repositoryCollisione.codiciProvati.last),
        );
        expect(nuovoCodice, repositoryCollisione.codiciProvati.last);
        expect(nuovoCodice, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
        final salvata = await repositoryCollisione.findById(legaScaduta.id);
        expect(salvata?.codiceInvito, nuovoCodice);
      },
    );

    /// Verifica D29 quando tutti i tentativi falliscono per collisione 23505.
    test('d29_collisione23505Sempre_rifiutaDopoTentativiMassimi', () async {
      final repositoryCollisione = _RepositoryCollisioneInvitoSempre();
      final controlCollisione = GestioneLegaControl(
        legaRepository: repositoryCollisione,
        orologio: () => adesso,
      );
      final legaScaduta = await repositoryCollisione.createLega(
        Lega(
          id: '',
          nome: 'Lega Collisione Sempre',
          tipologiaMatch: TipologiaMatch.cinqueVsCinque,
          privacy: PrivacyLega.privata,
          codiceInvito: 'OLD23456',
          scadenzaCodiceInvito: adesso.subtract(const Duration(seconds: 1)),
        ),
        idAmministratore,
      );

      await expectLater(
        controlCollisione.generaCodiceInvito(
          idLega: legaScaduta.id,
          idGiocatore: idAmministratore,
        ),
        throwsA(
          isA<AppException>().having((error) => error.code, 'codice', '23505'),
        ),
      );
      expect(repositoryCollisione.tentativi, 5);
      final salvata = await repositoryCollisione.findById(legaScaduta.id);
      expect(salvata?.codiceInvito, 'OLD23456');
    });
  });
}
