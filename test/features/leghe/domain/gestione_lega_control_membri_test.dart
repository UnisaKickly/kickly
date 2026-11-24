// Test di Gestione membri e amministrazione della lega (RF_LEG_3, KCK-222):
// copertura di F10 con TF_LEG_19..TF_LEG_23 (docs/test/cp_UC_ACC_1_UC_LEG_1.md
// §3.10). Preparazioni ed esiti attesi derivano dai frame, da RF_LEG_3 e dalle
// decisioni D13 (operazioni riservate) e D17 (unico amministratore), mai dal
// comportamento del codice. Si usa solo il repository in memoria.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  const idAmministratore = '00000000-0000-4000-8000-000000000201';
  const idMembro = '00000000-0000-4000-8000-000000000202';
  const idAltroMembro = '00000000-0000-4000-8000-000000000203';
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

  /// Prepara una lega amministrata da [idAmministratore] con due membri
  /// ordinari ([idMembro] e [idAltroMembro]) e ne restituisce l'id.
  ///
  /// La lega viene creata tramite il Control (come farebbe l'utente) e i
  /// membri vengono aggiunti direttamente nel repository in memoria.
  Future<String> creaLegaConMembri() async {
    final lega = await control.creaLega(
      nome: 'Lega Membri',
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
      idGiocatore: idAmministratore,
    );
    await repository.aggiungiMembro(lega.id, idMembro);
    await repository.aggiungiMembro(lega.id, idAltroMembro);
    return lega.id;
  }

  /// Fotografia di membri e ruoli letta dal repository, per confrontare lo
  /// stato prima e dopo un'operazione.
  Future<Map<String, bool>> statoMembri(String idLega) async {
    final membri = await repository.findMembri(idLega);
    return {
      for (final m in membri) m: await repository.isAmministratore(idLega, m),
    };
  }

  group('F10 Gestione membri (RF_LEG_3)', () {
    // TF_LEG_19 - amministratore, visualizza la lista.
    // Preparazione: lega con piu' membri (amministratore + due ordinari).
    // Esito atteso: l'amministratore visualizza la lista dei membri
    // (RF_LEG_3: "visualizzare la lista dei membri"), con il ruolo di ognuno.
    test('tf_leg_19_amministratore_visualizzaListaMembri', () async {
      final idLega = await creaLegaConMembri();

      final membri = await control.visualizzaMembri(
        idLega: idLega,
        idGiocatore: idAmministratore,
      );

      // La lista contiene tutti e soli i membri della lega.
      expect(membri.map((m) => m.idGiocatore).toSet(), {
        idAmministratore,
        idMembro,
        idAltroMembro,
      });
      expect(membri, hasLength(3));
      // Il ruolo mostrato corrisponde a quello della lega.
      final ruoli = {for (final m in membri) m.idGiocatore: m.amministratore};
      expect(ruoli[idAmministratore], isTrue);
      expect(ruoli[idMembro], isFalse);
      expect(ruoli[idAltroMembro], isFalse);
      // La sola visualizzazione non modifica lo stato.
      expect(await statoMembri(idLega), {
        idAmministratore: true,
        idMembro: false,
        idAltroMembro: false,
      });
    });

    // TF_LEG_20 - amministratore, promuove un membro ordinario.
    // Preparazione: lega con almeno un membro ordinario.
    // Esito atteso: il membro diventa amministratore della lega e resta tra
    // i membri (RF_LEG_3: "promuovere un altro giocatore ad amministratore").
    test('tf_leg_20_amministratore_promuoveMembroOrdinario', () async {
      final idLega = await creaLegaConMembri();

      await control.promuoviAdAmministratore(
        idLega: idLega,
        idMembro: idMembro,
        idGiocatore: idAmministratore,
      );

      // Stato dopo: il membro promosso e' amministratore e resta membro;
      // gli altri ruoli non cambiano.
      expect(await repository.isAmministratore(idLega, idMembro), isTrue);
      expect(await repository.findMembri(idLega), contains(idMembro));
      expect(await statoMembri(idLega), {
        idAmministratore: true,
        idMembro: true,
        idAltroMembro: false,
      });
      // Anche la lista visualizzata dall'amministratore riflette il nuovo ruolo.
      final membri = await control.visualizzaMembri(
        idLega: idLega,
        idGiocatore: idAmministratore,
      );
      final ruoli = {for (final m in membri) m.idGiocatore: m.amministratore};
      expect(ruoli[idMembro], isTrue);
    });

    // TF_LEG_21 - amministratore, rimuove un membro ordinario.
    // Preparazione: lega con almeno un membro ordinario.
    // Esito atteso: il membro e' rimosso dalla lega e la lista dei membri e'
    // aggiornata (RF_LEG_3: "rimuovere un membro dalla lega").
    test('tf_leg_21_amministratore_rimuoveMembroOrdinario', () async {
      final idLega = await creaLegaConMembri();

      await control.rimuoviMembro(
        idLega: idLega,
        idMembro: idMembro,
        idGiocatore: idAmministratore,
      );

      // Stato dopo nel repository: il membro non c'e' piu', gli altri si'.
      expect(await statoMembri(idLega), {
        idAmministratore: true,
        idAltroMembro: false,
      });
      // La lista visualizzata e' aggiornata.
      final membri = await control.visualizzaMembri(
        idLega: idLega,
        idGiocatore: idAmministratore,
      );
      expect(membri.map((m) => m.idGiocatore).toSet(), {
        idAmministratore,
        idAltroMembro,
      });
    });

    // TF_LEG_22 - unico amministratore che rimuove se stesso.
    // Preparazione: l'utente e' l'unico amministratore della lega.
    // Esito atteso (class diagram 1..* amministratori, D17): la richiesta e'
    // rifiutata con "Nomina un altro amministratore prima di uscire";
    // l'utente resta amministratore e membro della lega.
    test('tf_leg_22_unicoAmministratore_rimuoveSeStesso_rifiuta', () async {
      final idLega = await creaLegaConMembri();
      final prima = await statoMembri(idLega);

      await expectLater(
        control.rimuoviMembro(
          idLega: idLega,
          idMembro: idAmministratore,
          idGiocatore: idAmministratore,
        ),
        throwsA(
          isA<UnicoAmministratoreException>().having(
            (e) => e.message,
            'message',
            'Nomina un altro amministratore prima di uscire',
          ),
        ),
      );

      // Stato dopo: l'utente e' ancora membro e amministratore, nulla cambia.
      expect(await repository.findMembri(idLega), contains(idAmministratore));
      expect(
        await repository.isAmministratore(idLega, idAmministratore),
        isTrue,
      );
      expect(await statoMembri(idLega), prima);
    });

    // TF_LEG_23 - membro non amministratore.
    // Preparazione: membro ordinario che prova a promuovere o rimuovere.
    // Esito atteso (D13): i comandi non sono visibili al membro (lato GUI,
    // fuori dall'ambito di questo test sul Control); una richiesta diretta
    // viene rifiutata con un messaggio di errore e la lista dei membri resta
    // invariata. Si verificano sia la promozione sia la rimozione.
    test('tf_leg_23_membroOrdinario_promuoveORimuove_rifiuta', () async {
      final idLega = await creaLegaConMembri();
      final prima = await statoMembri(idLega);

      // Promozione richiesta direttamente da un membro ordinario.
      await expectLater(
        control.promuoviAdAmministratore(
          idLega: idLega,
          idMembro: idAltroMembro,
          idGiocatore: idMembro,
        ),
        throwsA(
          isA<GestioneMembriNonPermessaException>().having(
            (e) => e.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
      // Membri e ruoli invariati dopo la promozione rifiutata.
      expect(await statoMembri(idLega), prima);
      expect(await repository.isAmministratore(idLega, idAltroMembro), isFalse);

      // Rimozione richiesta direttamente da un membro ordinario.
      await expectLater(
        control.rimuoviMembro(
          idLega: idLega,
          idMembro: idAltroMembro,
          idGiocatore: idMembro,
        ),
        throwsA(
          isA<GestioneMembriNonPermessaException>().having(
            (e) => e.message,
            'message',
            isNotEmpty,
          ),
        ),
      );
      // Membri e ruoli invariati dopo la rimozione rifiutata.
      expect(await statoMembri(idLega), prima);
      expect(await repository.findMembri(idLega), contains(idAltroMembro));
    });
  });
}
