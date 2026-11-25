// Test di serializzazione dell'entity Partita e delle sue costanti.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, gli attributi facoltativi, la conversione in UTC di
// una data locale, i valori ammessi delle CHECK della migration B e la mappa
// delle transizioni confrontata con lo statechart SCD_PAR_StatoPartita.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/partite/domain/partita.dart';

void main() {
  // Riga fittizia di `partita` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000030',
    'giocatore_id': '3c9e5f10-0000-4000-8000-000000000001',
    'lega_id': '3c9e5f10-0000-4000-8000-000000000020',
    'data_ora': '2026-11-27T20:00:00+00:00',
    'tipologia': '5v5',
    'privacy': 'privata',
    'num_partecipanti_richiesti': 10,
    'stato': 'Aperta',
    'link_condivisione': 'https://kickly.test/p/LINK-TEST',
  };

  group('Partita fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final partita = Partita(
        id: '3c9e5f10-0000-4000-8000-000000000030',
        giocatoreId: '3c9e5f10-0000-4000-8000-000000000001',
        legaId: '3c9e5f10-0000-4000-8000-000000000020',
        dataOra: DateTime.utc(2026, 11, 27, 20),
        tipologia: TipologiaPartita.cinqueVsCinque,
        privacy: PrivacyPartita.privata,
        numPartecipantiRichiesti: 10,
        stato: StatoPartita.aperta,
        linkCondivisione: 'https://kickly.test/p/LINK-TEST',
      );

      expect(Partita.fromJson(partita.toJson()).toJson(), partita.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final partita = Partita.fromJson(rigaSupabase());

      expect(partita.id, '3c9e5f10-0000-4000-8000-000000000030');
      expect(partita.giocatoreId, '3c9e5f10-0000-4000-8000-000000000001');
      expect(partita.legaId, '3c9e5f10-0000-4000-8000-000000000020');
      expect(partita.dataOra, DateTime.utc(2026, 11, 27, 20));
      expect(partita.tipologia, '5v5');
      expect(partita.privacy, 'privata');
      expect(partita.numPartecipantiRichiesti, 10);
      expect(partita.stato, 'Aperta');
      expect(partita.linkCondivisione, 'https://kickly.test/p/LINK-TEST');
    });

    test('partita senza lega e senza link: null letti e riscritti', () {
      final riga = rigaSupabase()
        ..['privacy'] = 'pubblica'
        ..['lega_id'] = null
        ..['link_condivisione'] = null;

      final partita = Partita.fromJson(riga);

      expect(partita.legaId, isNull);
      expect(partita.linkCondivisione, isNull);
      expect(partita.toJson()['lega_id'], isNull);
      expect(partita.toJson()['link_condivisione'], isNull);
    });

    test('toJson usa le colonne della migration B', () {
      final json = Partita.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'giocatore_id',
        'lega_id',
        'data_ora',
        'tipologia',
        'privacy',
        'num_partecipanti_richiesti',
        'stato',
        'link_condivisione',
      });
      expect(json['data_ora'], '2026-11-27T20:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: data costruita nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 27, 20, 30);
      final partita = Partita.fromJson(rigaSupabase());
      final conDataLocale = Partita(
        id: partita.id,
        giocatoreId: partita.giocatoreId,
        legaId: partita.legaId,
        dataOra: dataLocale,
        tipologia: partita.tipologia,
        privacy: partita.privacy,
        numPartecipantiRichiesti: partita.numPartecipantiRichiesti,
        stato: partita.stato,
        linkCondivisione: partita.linkCondivisione,
      );

      final scritta = conDataLocale.toJson()['data_ora'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(
        Partita.fromJson(conDataLocale.toJson()).toJson(),
        conDataLocale.toJson(),
      );
    });

    test('legge la data con i microsecondi come la restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['data_ora'] = '2026-11-27T20:00:00.123456+00:00';

      final partita = Partita.fromJson(riga);

      expect(partita.dataOra, DateTime.utc(2026, 11, 27, 20, 0, 0, 123, 456));

      final json = partita.toJson();
      expect(json['data_ora'], '2026-11-27T20:00:00.123456Z');
      expect(Partita.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test('TipologiaPartita coincide con la CHECK partita_tipologia_check', () {
      expect(TipologiaPartita.valori, {
        '5v5',
        '6v6',
        '7v7',
        '8v8',
        '9v9',
        '10v10',
        '11v11',
      });
      expect(TipologiaPartita.cinqueVsCinque, '5v5');
      expect(TipologiaPartita.seiVsSei, '6v6');
      expect(TipologiaPartita.setteVsSette, '7v7');
      expect(TipologiaPartita.ottoVsOtto, '8v8');
      expect(TipologiaPartita.noveVsNove, '9v9');
      expect(TipologiaPartita.dieciVsDieci, '10v10');
      expect(TipologiaPartita.undiciVsUndici, '11v11');
    });

    test('PrivacyPartita coincide con la CHECK partita_privacy_check', () {
      expect(PrivacyPartita.valori, {'pubblica', 'privata'});
      expect(PrivacyPartita.pubblica, 'pubblica');
      expect(PrivacyPartita.privata, 'privata');
    });

    test('StatoPartita coincide con la CHECK partita_stato_check', () {
      expect(StatoPartita.valori, {
        'Aperta',
        'Completa',
        'Confermata',
        'Conclusa',
        'Annullata',
      });
      expect(StatoPartita.aperta, 'Aperta');
      expect(StatoPartita.completa, 'Completa');
      expect(StatoPartita.confermata, 'Confermata');
      expect(StatoPartita.conclusa, 'Conclusa');
      expect(StatoPartita.annullata, 'Annullata');
    });
  });

  group('StatoPartita.transizioniAmmesse', () {
    // Tabella attesa scritta a mano da docs/modelli/statechart_partita.puml
    // (non ricavata dalla mappa): per ogni stato, gli stati di arrivo.
    const attesa = <String, Set<String>>{
      'Aperta': {'Completa', 'Annullata'},
      'Completa': {'Aperta', 'Confermata', 'Annullata'},
      'Confermata': {'Conclusa', 'Annullata'},
      'Conclusa': <String>{},
      'Annullata': <String>{},
    };

    // I 7 passaggi ammessi dello statechart (Completa -> Annullata ha due
    // eventi ma e' una sola coppia).
    const passaggiAmmessi = [
      ('Aperta', 'Completa'),
      ('Completa', 'Aperta'),
      ('Completa', 'Confermata'),
      ('Confermata', 'Conclusa'),
      ('Aperta', 'Annullata'),
      ('Completa', 'Annullata'),
      ('Confermata', 'Annullata'),
    ];

    test('coincide con la tabella attesa dello statechart', () {
      expect(StatoPartita.transizioniAmmesse, attesa);
    });

    test('le chiavi sono gli stati di StatoPartita.valori', () {
      expect(StatoPartita.transizioniAmmesse.keys.toSet(), StatoPartita.valori);
    });

    test('ogni stato di arrivo e\' uno dei valori ammessi', () {
      for (final arrivi in StatoPartita.transizioniAmmesse.values) {
        expect(StatoPartita.valori.containsAll(arrivi), isTrue);
      }
    });

    test('contiene i 7 passaggi ammessi dello statechart', () {
      for (final (da, a) in passaggiAmmessi) {
        expect(
          StatoPartita.transizioniAmmesse[da],
          contains(a),
          reason: '$da -> $a',
        );
      }
      final totale = StatoPartita.transizioniAmmesse.values.fold<int>(
        0,
        (somma, arrivi) => somma + arrivi.length,
      );
      expect(totale, 7);
    });

    test('gli stati finali Conclusa e Annullata non hanno transizioni', () {
      expect(StatoPartita.transizioniAmmesse['Conclusa'], isEmpty);
      expect(StatoPartita.transizioniAmmesse['Annullata'], isEmpty);
    });

    test('vietato Aperta -> Confermata', () {
      expect(
        StatoPartita.transizioniAmmesse['Aperta'],
        isNot(contains('Confermata')),
      );
    });

    test('vietato Confermata -> Completa', () {
      expect(
        StatoPartita.transizioniAmmesse['Confermata'],
        isNot(contains('Completa')),
      );
    });

    test('vietato Annullata -> Aperta', () {
      expect(
        StatoPartita.transizioniAmmesse['Annullata'],
        isNot(contains('Aperta')),
      );
    });

    test('vietato Conclusa -> Annullata', () {
      expect(
        StatoPartita.transizioniAmmesse['Conclusa'],
        isNot(contains('Annullata')),
      );
    });
  });
}
