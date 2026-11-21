// Test di serializzazione dell'entity Transazione e delle sue costanti.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, le chiavi esterne e la data dell'esito facoltative,
// il rimborso con la transazione originaria, l'importo intero letto come
// double, la conversione in UTC di una data locale e i valori ammessi delle
// CHECK della Migration C (D27).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/pagamenti/domain/transazione.dart';

void main() {
  // Riga fittizia di `transazione` (un accredito) come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000090',
    'quota_id': null,
    'prenotazione_id': '3c9e5f10-0000-4000-8000-000000000040',
    'gestore_campo_id': '3c9e5f10-0000-4000-8000-000000000003',
    'transazione_originaria_id': null,
    'tipo': 'accredito',
    'importo': 57.0,
    'stato': 'completata',
    'data_esito': '2026-11-27T21:00:00+00:00',
    'riferimento_esterno': 'evt_test_accredito_0001',
  };

  group('Transazione fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final transazione = Transazione(
        id: '3c9e5f10-0000-4000-8000-000000000090',
        prenotazioneId: '3c9e5f10-0000-4000-8000-000000000040',
        gestoreCampoId: '3c9e5f10-0000-4000-8000-000000000003',
        tipo: TipoTransazione.accredito,
        importo: 57,
        stato: StatoTransazione.completata,
        dataEsito: DateTime.utc(2026, 11, 27, 21),
        riferimentoEsterno: 'evt_test_accredito_0001',
      );

      expect(
        Transazione.fromJson(transazione.toJson()).toJson(),
        transazione.toJson(),
      );
    });

    test('legge una riga di Supabase campo per campo', () {
      final transazione = Transazione.fromJson(rigaSupabase());

      expect(transazione.id, '3c9e5f10-0000-4000-8000-000000000090');
      expect(transazione.quotaId, isNull);
      expect(
        transazione.prenotazioneId,
        '3c9e5f10-0000-4000-8000-000000000040',
      );
      expect(
        transazione.gestoreCampoId,
        '3c9e5f10-0000-4000-8000-000000000003',
      );
      expect(transazione.transazioneOriginariaId, isNull);
      expect(transazione.tipo, 'accredito');
      expect(transazione.importo, 57.0);
      expect(transazione.stato, 'completata');
      expect(transazione.dataEsito, DateTime.utc(2026, 11, 27, 21));
      expect(transazione.riferimentoEsterno, 'evt_test_accredito_0001');
    });

    test('transazione in attesa senza chiavi esterne ne\' esito: null letti e '
        'riscritti', () {
      final riga = rigaSupabase()
        ..['prenotazione_id'] = null
        ..['gestore_campo_id'] = null
        ..['stato'] = 'in_attesa'
        ..['data_esito'] = null;

      final transazione = Transazione.fromJson(riga);
      final json = transazione.toJson();

      expect(transazione.quotaId, isNull);
      expect(transazione.prenotazioneId, isNull);
      expect(transazione.gestoreCampoId, isNull);
      expect(transazione.transazioneOriginariaId, isNull);
      expect(transazione.dataEsito, isNull);
      expect(json['quota_id'], isNull);
      expect(json['prenotazione_id'], isNull);
      expect(json['gestore_campo_id'], isNull);
      expect(json['transazione_originaria_id'], isNull);
      expect(json['data_esito'], isNull);
    });

    test('rimborso con quota e transazione originaria', () {
      final riga = rigaSupabase()
        ..['quota_id'] = '3c9e5f10-0000-4000-8000-000000000080'
        ..['prenotazione_id'] = null
        ..['gestore_campo_id'] = null
        ..['transazione_originaria_id'] = '3c9e5f10-0000-4000-8000-000000000091'
        ..['tipo'] = 'rimborso'
        ..['importo'] = 6.5
        ..['riferimento_esterno'] = 'evt_test_rimborso_0001';

      final transazione = Transazione.fromJson(riga);

      expect(transazione.tipo, 'rimborso');
      expect(transazione.quotaId, '3c9e5f10-0000-4000-8000-000000000080');
      expect(
        transazione.transazioneOriginariaId,
        '3c9e5f10-0000-4000-8000-000000000091',
      );
      expect(
        transazione.toJson()['transazione_originaria_id'],
        '3c9e5f10-0000-4000-8000-000000000091',
      );
    });

    test('importo intero letto come double', () {
      // Preparazione: PostgREST puo' restituire un numeric senza decimali.
      final riga = rigaSupabase()..['importo'] = 57;

      final transazione = Transazione.fromJson(riga);

      expect(transazione.importo, isA<double>());
      expect(transazione.importo, 57.0);
    });

    test('toJson usa le colonne della Migration C', () {
      final json = Transazione.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'quota_id',
        'prenotazione_id',
        'gestore_campo_id',
        'transazione_originaria_id',
        'tipo',
        'importo',
        'stato',
        'data_esito',
        'riferimento_esterno',
      });
      expect(json['data_esito'], '2026-11-27T21:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: data dell'esito costruita nel fuso locale, non con
      // DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 27, 21, 10);
      final transazione = Transazione(
        id: '3c9e5f10-0000-4000-8000-000000000091',
        quotaId: '3c9e5f10-0000-4000-8000-000000000080',
        tipo: TipoTransazione.pagamento,
        importo: 6.5,
        stato: StatoTransazione.fallita,
        dataEsito: dataLocale,
        riferimentoEsterno: 'evt_test_pagamento_0001',
      );

      final scritta = transazione.toJson()['data_esito'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(
        Transazione.fromJson(transazione.toJson()).toJson(),
        transazione.toJson(),
      );
    });

    test('legge la data dell\'esito con i microsecondi come la restituisce '
        'PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['data_esito'] = '2026-11-27T21:00:00.123456+00:00';

      final transazione = Transazione.fromJson(riga);

      expect(
        transazione.dataEsito,
        DateTime.utc(2026, 11, 27, 21, 0, 0, 123, 456),
      );

      final json = transazione.toJson();
      expect(json['data_esito'], '2026-11-27T21:00:00.123456Z');
      expect(Transazione.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test('TipoTransazione coincide con la CHECK transazione_tipo_check', () {
      expect(TipoTransazione.valori, {'pagamento', 'rimborso', 'accredito'});
      expect(TipoTransazione.pagamento, 'pagamento');
      expect(TipoTransazione.rimborso, 'rimborso');
      expect(TipoTransazione.accredito, 'accredito');
    });

    test('StatoTransazione coincide con la CHECK transazione_stato_check', () {
      expect(StatoTransazione.valori, {'in_attesa', 'completata', 'fallita'});
      expect(StatoTransazione.inAttesa, 'in_attesa');
      expect(StatoTransazione.completata, 'completata');
      expect(StatoTransazione.fallita, 'fallita');
    });
  });
}
