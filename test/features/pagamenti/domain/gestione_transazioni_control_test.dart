// Test applicativi per RF_PAG_2.
//
// Coprono TF_PAG_01, TF_PAG_02, TF_PAG_08 e TF_PAG_11.
// Preparazione ed esiti attesi sono presi da UC_PAG_1 e dal category partition;
// repository e gateway sono in memoria, senza accesso reale al DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/pagamenti/data/in_memory_gateway_pagamenti.dart';
import 'package:kickly/features/pagamenti/data/in_memory_quota_repository.dart';
import 'package:kickly/features/pagamenti/data/in_memory_transazione_repository.dart';
import 'package:kickly/features/pagamenti/domain/gestione_transazioni_control.dart';
import 'package:kickly/features/pagamenti/domain/quota.dart';
import 'package:kickly/features/pagamenti/domain/transazione.dart';

void main() {
  const partitaId = 'partita-pagamenti';
  const prenotazioneId = 'prenotazione-pagamenti';

  Quota quota({
    required String id,
    required String partecipazioneId,
    String stato = StatoVersamento.versata,
  }) {
    return Quota(
      id: id,
      partecipazioneId: partecipazioneId,
      importo: 6,
      statoVersamento: stato,
      termineVersamento: DateTime.utc(2026, 11, 27, 17),
    );
  }

  late InMemoryQuotaRepository quote;
  late InMemoryTransazioneRepository transazioni;
  late InMemoryGatewayPagamenti gateway;
  late GestioneTransazioniControl control;

  setUp(() async {
    quote = InMemoryQuotaRepository();
    quote.collegaPartecipazioneAPartita('partecipazione-1', partitaId);
    quote.collegaPartecipazioneAPartita('partecipazione-2', partitaId);
    await quote.createQuota(
      quota(id: 'quota-1', partecipazioneId: 'partecipazione-1'),
    );
    await quote.createQuota(
      quota(id: 'quota-2', partecipazioneId: 'partecipazione-2'),
    );

    transazioni = InMemoryTransazioneRepository();
    gateway = InMemoryGatewayPagamenti();
    control = GestioneTransazioniControl(
      transazioneRepository: transazioni,
      quotaRepository: quote,
      gatewayPagamenti: gateway,
    );
  });

  // TF_PAG_02: ultima quota versata e account Gestore collegato.
  // Preparazione: tutte le quote della partita sono versate.
  // Esito atteso lato Control: viene disposta una sola richiesta di accredito;
  // il calcolo al netto della commissione resta nella Edge Function server.
  test('tf_pag_02_ultimaQuotaAccreditataAlGestore', () async {
    await control.disponiAccredito(prenotazioneId, partitaId);

    expect(gateway.richiesteAccredito, [prenotazioneId]);
  });

  // TF_PAG_11: ultima quota versata e account Stripe del Gestore non collegato.
  // Preparazione: tutte le quote sono versate e il Control non dispone dati
  // sull'account del Gestore presso il fornitore.
  // Esito atteso lato Control: invoca gatewayPagamenti.disponiAccredito una volta.
  // La verifica dell'account Stripe e la registrazione dello stato in_attesa
  // spettano alla Edge Function lato server.
  test('tf_pag_11_accountGestoreNonCollegatoInvocaGateway', () async {
    await control.disponiAccredito(prenotazioneId, partitaId);

    expect(gateway.richiesteAccredito, [prenotazioneId]);
    expect(await transazioni.findByPrenotazione(prenotazioneId), isEmpty);
  });

  // TF_PAG_01: restano quote incomplete.
  // Preparazione: almeno una quota della partita e' da versare.
  // Esito atteso: l'accredito viene rifiutato e il gateway non riceve chiamate.
  test('tf_pag_01_quoteIncompleteNonDispongonoAccredito', () async {
    await quote.updateStatoVersamento('quota-2', StatoVersamento.daVersare);

    await expectLater(
      control.disponiAccredito(prenotazioneId, partitaId),
      throwsA(isA<QuoteIncompleteException>()),
    );
    expect(gateway.richiesteAccredito, isEmpty);
  });

  // TF_PAG_08: doppio accredito con riferimento gia' registrato.
  // Preparazione: esiste un accredito della prenotazione gia' completato.
  // Esito atteso: il Control rifiuta la seconda disposizione e il gateway non
  // riceve altre chiamate.
  test('tf_pag_08_doppioAccreditoRifiutato', () async {
    transazioni = InMemoryTransazioneRepository(
      transazioni: [
        Transazione(
          id: 'accredito-esistente',
          prenotazioneId: prenotazioneId,
          gestoreCampoId: 'gestore-pagamenti',
          tipo: TipoTransazione.accredito,
          importo: 57,
          stato: StatoTransazione.completata,
          riferimentoEsterno: 'evt-accredito-esistente',
        ),
      ],
    );
    control = GestioneTransazioniControl(
      transazioneRepository: transazioni,
      quotaRepository: quote,
      gatewayPagamenti: gateway,
    );

    await expectLater(
      control.disponiAccredito(prenotazioneId, partitaId),
      throwsA(isA<DoppioAccreditoException>()),
    );
    expect(gateway.richiesteAccredito, isEmpty);
  });

  test('accreditoFallitaNonImpedisceUnaNuovaDisposizione', () async {
    // Preparazione: esiste un tentativo precedentemente fallito.
    // Esito atteso: il Control puo' disporre di nuovo l'accredito.
    transazioni = InMemoryTransazioneRepository(
      transazioni: [
        Transazione(
          id: 'accredito-fallito',
          prenotazioneId: prenotazioneId,
          gestoreCampoId: 'gestore-pagamenti',
          tipo: TipoTransazione.accredito,
          importo: 57,
          stato: StatoTransazione.fallita,
          riferimentoEsterno: 'evt-accredito-fallito',
        ),
      ],
    );
    control = GestioneTransazioniControl(
      transazioneRepository: transazioni,
      quotaRepository: quote,
      gatewayPagamenti: gateway,
    );

    await control.disponiAccredito(prenotazioneId, partitaId);

    expect(gateway.richiesteAccredito, [prenotazioneId]);
  });

  test('consultaAccreditiRestituisceSoloGliAccreditiDelGestore', () async {
    // Preparazione: sono presenti accrediti di due gestori.
    // Esito atteso: la consultazione restituisce solo quelli del Gestore richiesto.
    transazioni = InMemoryTransazioneRepository(
      transazioni: [
        Transazione(
          id: 'accredito-1',
          prenotazioneId: prenotazioneId,
          gestoreCampoId: 'gestore-1',
          tipo: TipoTransazione.accredito,
          importo: 57,
          stato: StatoTransazione.completata,
          riferimentoEsterno: 'evt-accredito-1',
        ),
        Transazione(
          id: 'accredito-2',
          prenotazioneId: 'prenotazione-2',
          gestoreCampoId: 'gestore-2',
          tipo: TipoTransazione.accredito,
          importo: 57,
          stato: StatoTransazione.completata,
          riferimentoEsterno: 'evt-accredito-2',
        ),
      ],
    );
    control = GestioneTransazioniControl(
      transazioneRepository: transazioni,
      quotaRepository: quote,
      gatewayPagamenti: gateway,
    );

    final accrediti = await control.consultaAccrediti('gestore-1');

    expect(accrediti.map((accredito) => accredito.id), {'accredito-1'});
  });
}
