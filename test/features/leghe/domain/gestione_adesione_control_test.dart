// Test di adesione alle leghe (RF_LEG_2, KCK-256):
// copertura di TF_LEG_12-TF_LEG_18 e dell'accesso diretto alle leghe private.
// Preparazioni ed esiti attesi derivano dai frame, da UC_LEG_1 e da D29.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_adesione_control.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  const idAmministratore = '00000000-0000-4000-8000-000000000201';
  const idGiocatore = '00000000-0000-4000-8000-000000000202';
  const codiceValido = 'ABCD2345';
  final adesso = DateTime.utc(2026, 11, 24, 10);

  late InMemoryLegaRepository repository;
  late GestioneAdesioneControl control;

  setUp(() {
    repository = InMemoryLegaRepository();
    control = GestioneAdesioneControl(
      legaRepository: repository,
      orologio: () => adesso,
    );
  });

  /// Crea una lega fittizia con un codice valido e scadenza controllata.
  ///
  /// [privacy] determina se la lega e' privata o pubblica. L'amministratore
  /// iniziale resta distinto da [idGiocatore], usato nelle operazioni di adesione.
  Future<Lega> creaLega({required String nome, required String privacy}) =>
      repository.createLega(
        Lega(
          id: '',
          nome: nome,
          tipologiaMatch: TipologiaMatch.cinqueVsCinque,
          privacy: privacy,
          codiceInvito: codiceValido,
          scadenzaCodiceInvito: adesso.add(
            GestioneLegaControl.durataCodiceInvito,
          ),
        ),
        idAmministratore,
      );

  /// Gruppo della F9: adesione tramite invito o accesso diretto.
  ///
  /// Ogni test controlla sia l'esito applicativo sia lo stato dei membri.
  group('F9 Adesione alla lega (UC_LEG_1 passi 6-7)', () {
    /// Verifica TF_LEG_12: Preparazione: un secondo giocatore inserisce il
    /// codice valido di una lega privata. Esito atteso: il sistema verifica
    /// l'invito e aggiunge il giocatore all'elenco dei membri.
    test('tf_leg_12_legaPrivataCodiceValido_aggiungeGiocatore', () async {
      final lega = await creaLega(
        nome: 'Lega Privata',
        privacy: PrivacyLega.privata,
      );

      final aderita = await control.uniscitiConCodice(
        codiceInvito: codiceValido,
        idGiocatore: idGiocatore,
      );

      expect(aderita.id, lega.id);
      final leghe = await repository.findByGiocatore(idGiocatore);
      expect(leghe.map((l) => l.id), contains(lega.id));
      expect(leghe, hasLength(1));
    });

    /// Verifica TF_LEG_13: Preparazione: un secondo giocatore inserisce il
    /// codice valido di una lega pubblica. Esito atteso: l'adesione viene
    /// accettata e il giocatore appare tra i membri.
    test('tf_leg_13_legaPubblicaCodiceValido_aggiungeGiocatore', () async {
      final lega = await creaLega(
        nome: 'Lega Pubblica',
        privacy: PrivacyLega.pubblica,
      );

      final aderita = await control.uniscitiConCodice(
        codiceInvito: codiceValido,
        idGiocatore: idGiocatore,
      );

      expect(aderita.id, lega.id);
      final leghe = await repository.findByGiocatore(idGiocatore);
      expect(leghe.map((l) => l.id), contains(lega.id));
      expect(leghe, hasLength(1));
    });

    /// Verifica TF_LEG_14: Preparazione: un giocatore trova una lega pubblica
    /// e usa l'accesso diretto senza invito. Esito atteso: il giocatore viene
    /// aggiunto senza fornire un codice.
    test('tf_leg_14_legaPubblicaAccessoDiretto_aggiungeGiocatore', () async {
      final lega = await creaLega(
        nome: 'Lega Pubblica Diretta',
        privacy: PrivacyLega.pubblica,
      );

      final aderita = await control.accediDirettamente(
        idLega: lega.id,
        idGiocatore: idGiocatore,
      );

      expect(aderita.id, lega.id);
      final leghe = await repository.findByGiocatore(idGiocatore);
      expect(leghe.map((l) => l.id), contains(lega.id));
      expect(leghe, hasLength(1));
    });

    /// Verifica TF_LEG_15: Preparazione: un giocatore apre il link canonico
    /// ricevuto per una lega. Esito atteso: il codice viene estratto dal link
    /// valido e il giocatore viene aggiunto come membro.
    test('tf_leg_15_linkInvitoValido_aggiungeGiocatore', () async {
      final lega = await creaLega(
        nome: 'Lega da Link',
        privacy: PrivacyLega.privata,
      );
      final link =
          'https://unisakickly.github.io/kickly/#/lega/invito/$codiceValido';

      final aderita = await control.uniscitiConLink(
        linkInvito: link,
        idGiocatore: idGiocatore,
      );

      expect(aderita.id, lega.id);
      final leghe = await repository.findByGiocatore(idGiocatore);
      expect(leghe.map((l) => l.id), contains(lega.id));
      expect(leghe, hasLength(1));
    });

    /// Verifica TF_LEG_16: Preparazione: il giocatore e' gia' membro della lega
    /// pubblica. Esito atteso: codice, link e accesso diretto rifiutano
    /// l'adesione con GiocatoreGiaMembroException e non creano duplicazioni.
    test('tf_leg_16_giocatoreGiaMembro_rifiutaSenzaDuplicazioni', () async {
      final lega = await creaLega(
        nome: 'Lega Gia Membro',
        privacy: PrivacyLega.pubblica,
      );
      await repository.aggiungiMembro(lega.id, idGiocatore);
      final link =
          'https://unisakickly.github.io/kickly/#/lega/invito/$codiceValido';

      await expectLater(
        control.uniscitiConCodice(
          codiceInvito: codiceValido,
          idGiocatore: idGiocatore,
        ),
        throwsA(isA<GiocatoreGiaMembroException>()),
      );
      await expectLater(
        control.uniscitiConLink(linkInvito: link, idGiocatore: idGiocatore),
        throwsA(isA<GiocatoreGiaMembroException>()),
      );
      await expectLater(
        control.accediDirettamente(idLega: lega.id, idGiocatore: idGiocatore),
        throwsA(isA<GiocatoreGiaMembroException>()),
      );

      final leghe = await repository.findByGiocatore(idGiocatore);
      expect(leghe, hasLength(1));
      expect(leghe.map((l) => l.id), contains(lega.id));
    });

    /// Verifica TF_LEG_17: Preparazione: il codice non identifica alcuna lega.
    /// Esito atteso: il codice inesistente produce
    /// CodiceInvitoNonValidoException; un dominio errato o un link incompleto
    /// producono LinkInvitoNonValidoException e nessuna adesione avviene.
    test('tf_leg_17_invitoErrato_rifiutaCodiceOLink', () async {
      await expectLater(
        control.uniscitiConCodice(
          codiceInvito: 'ZZZZ9999',
          idGiocatore: idGiocatore,
        ),
        throwsA(isA<CodiceInvitoNonValidoException>()),
      );
      await expectLater(
        control.uniscitiConLink(
          linkInvito: 'https://esempio.org/kickly/#/lega/invito/$codiceValido',
          idGiocatore: idGiocatore,
        ),
        throwsA(isA<LinkInvitoNonValidoException>()),
      );
      await expectLater(
        control.uniscitiConLink(
          linkInvito:
              'https://unisakickly.github.io/kickly/#/lega/invito/SHORT',
          idGiocatore: idGiocatore,
        ),
        throwsA(isA<LinkInvitoNonValidoException>()),
      );

      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });

    /// Verifica TF_LEG_18: Preparazione: una lega esiste ma il codice e'
    /// scaduto oltre i 7 giorni previsti da D29. Esito atteso:
    /// CodiceInvitoScadutoException e nessuna nuova adesione.
    test('tf_leg_18_invitoScaduto_rifiutaAdesione', () async {
      final lega = await creaLega(
        nome: 'Lega Codice Scaduto',
        privacy: PrivacyLega.privata,
      );
      final legaScaduta = Lega(
        id: lega.id,
        nome: lega.nome,
        tipologiaMatch: lega.tipologiaMatch,
        privacy: lega.privacy,
        codiceInvito: lega.codiceInvito,
        scadenzaCodiceInvito: adesso.subtract(
          GestioneLegaControl.durataCodiceInvito + const Duration(seconds: 1),
        ),
      );
      await repository.updateLega(legaScaduta);

      await expectLater(
        control.uniscitiConCodice(
          codiceInvito: codiceValido,
          idGiocatore: idGiocatore,
        ),
        throwsA(isA<CodiceInvitoScadutoException>()),
      );

      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });

    /// Verifica il caso alternativo: Preparazione: il giocatore tenta l'accesso
    /// diretto a una lega privata, senza invito. Esito atteso:
    /// LegaPrivataInvitoRichiestoException e nessuna adesione.
    test('legaPrivataAccessoDiretto_rifiutaSenzaInvito', () async {
      final lega = await creaLega(
        nome: 'Lega Privata Diretto',
        privacy: PrivacyLega.privata,
      );

      await expectLater(
        control.accediDirettamente(idLega: lega.id, idGiocatore: idGiocatore),
        throwsA(isA<LegaPrivataInvitoRichiestoException>()),
      );

      expect(await repository.findByGiocatore(idGiocatore), isEmpty);
    });
  });
}
