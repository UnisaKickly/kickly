import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/pagamenti/data/in_memory_transazione_repository.dart';
import 'package:kickly/features/pagamenti/domain/transazione.dart';

/// Costruisce una transazione fittizia per i test in memoria.
Transazione transazione({
  String id = 'transazione-1',
  String? quotaId = 'quota-1',
  String? prenotazioneId = 'prenotazione-1',
  String? gestoreCampoId = 'gestore-1',
  String riferimentoEsterno = 'evt-test-1',
}) {
  return Transazione(
    id: id,
    quotaId: quotaId,
    prenotazioneId: prenotazioneId,
    gestoreCampoId: gestoreCampoId,
    tipo: TipoTransazione.pagamento,
    importo: 6,
    stato: StatoTransazione.completata,
    dataEsito: DateTime.utc(2026, 11, 22, 20),
    riferimentoEsterno: riferimentoEsterno,
  );
}

void main() {
  test('findById restituisce la transazione trovata', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    final found = await repository.findById('transazione-1');

    expect(found?.id, 'transazione-1');
  });

  test('findById restituisce null quando manca', () async {
    final repository = InMemoryTransazioneRepository();

    expect(await repository.findById('inesistente'), isNull);
  });

  test('findByQuota restituisce la lista nominale', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [
        transazione(),
        transazione(id: 'transazione-2', quotaId: 'quota-1'),
        transazione(id: 'transazione-3', quotaId: 'quota-2'),
      ],
    );

    final found = await repository.findByQuota('quota-1');

    expect(found, hasLength(2));
  });

  test('findByQuota restituisce una lista vuota', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    expect(await repository.findByQuota('quota-senza-transazioni'), isEmpty);
  });

  test('findByPrenotazione restituisce la lista nominale', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [
        transazione(),
        transazione(id: 'transazione-2', prenotazioneId: 'prenotazione-1'),
        transazione(id: 'transazione-3', prenotazioneId: 'prenotazione-2'),
      ],
    );

    final found = await repository.findByPrenotazione('prenotazione-1');

    expect(found, hasLength(2));
  });

  test('findByPrenotazione restituisce una lista vuota', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    expect(
      await repository.findByPrenotazione('prenotazione-senza-transazioni'),
      isEmpty,
    );
  });

  test('findByGestoreCampo restituisce la lista nominale', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [
        transazione(),
        transazione(id: 'transazione-2', gestoreCampoId: 'gestore-1'),
        transazione(id: 'transazione-3', gestoreCampoId: 'gestore-2'),
      ],
    );

    final found = await repository.findByGestoreCampo('gestore-1');

    expect(found, hasLength(2));
  });

  test('findByGestoreCampo restituisce una lista vuota', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    expect(
      await repository.findByGestoreCampo('gestore-senza-transazioni'),
      isEmpty,
    );
  });

  test('findByRiferimentoEsterno trova la transazione', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    final found = await repository.findByRiferimentoEsterno('evt-test-1');

    expect(found?.id, 'transazione-1');
  });

  test('findByRiferimentoEsterno restituisce null', () async {
    final repository = InMemoryTransazioneRepository(
      transazioni: [transazione()],
    );

    expect(
      await repository.findByRiferimentoEsterno('riferimento-inesistente'),
      isNull,
    );
  });

  test('l implementazione in memoria espone esclusivamente letture', () {
    // Verifica strutturale: le transazioni sono create e aggiornate dalle Edge
    // Functions, quindi il repository in memoria non deve offrirne mutazioni.
    final source = File(
      'lib/features/pagamenti/data/in_memory_transazione_repository.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('creaTransazione')));
    expect(source, isNot(contains('createTransazione')));
    expect(source, isNot(contains('update')));
    expect(source, isNot(contains('delete')));
    expect(source, isNot(contains('insert')));
  });
}
