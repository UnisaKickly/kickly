// Test di serializzazione dell'entity Partecipazione e di RispostaStato.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, gol e assist a 0, la conversione in UTC di una data
// locale e i valori ammessi della CHECK della migration B (D24).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/partite/domain/partecipazione.dart';

void main() {
  // Riga fittizia di `partecipazione` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000050',
    'giocatore_id': '3c9e5f10-0000-4000-8000-000000000002',
    'partita_id': '3c9e5f10-0000-4000-8000-000000000030',
    'risposta_stato': 'confermata',
    'data_risposta': '2026-11-21T09:30:00+00:00',
    'gol_partita': 2,
    'assist_partita': 1,
  };

  group('Partecipazione fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final partecipazione = Partecipazione(
        id: '3c9e5f10-0000-4000-8000-000000000050',
        giocatoreId: '3c9e5f10-0000-4000-8000-000000000002',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        rispostaStato: RispostaStato.confermata,
        dataRisposta: DateTime.utc(2026, 11, 21, 9, 30),
        golPartita: 2,
        assistPartita: 1,
      );

      expect(
        Partecipazione.fromJson(partecipazione.toJson()).toJson(),
        partecipazione.toJson(),
      );
    });

    test('legge una riga di Supabase campo per campo', () {
      final partecipazione = Partecipazione.fromJson(rigaSupabase());

      expect(partecipazione.id, '3c9e5f10-0000-4000-8000-000000000050');
      expect(
        partecipazione.giocatoreId,
        '3c9e5f10-0000-4000-8000-000000000002',
      );
      expect(partecipazione.partitaId, '3c9e5f10-0000-4000-8000-000000000030');
      expect(partecipazione.rispostaStato, 'confermata');
      expect(partecipazione.dataRisposta, DateTime.utc(2026, 11, 21, 9, 30));
      expect(partecipazione.golPartita, 2);
      expect(partecipazione.assistPartita, 1);
    });

    test('presenza ritirata con gol e assist a 0 letti e riscritti', () {
      final riga = rigaSupabase()
        ..['risposta_stato'] = 'ritirata'
        ..['gol_partita'] = 0
        ..['assist_partita'] = 0;

      final partecipazione = Partecipazione.fromJson(riga);

      expect(partecipazione.rispostaStato, 'ritirata');
      expect(partecipazione.golPartita, 0);
      expect(partecipazione.assistPartita, 0);
      expect(partecipazione.toJson()['gol_partita'], 0);
      expect(partecipazione.toJson()['assist_partita'], 0);
    });

    test('toJson usa le colonne della migration B', () {
      final json = Partecipazione.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'giocatore_id',
        'partita_id',
        'risposta_stato',
        'data_risposta',
        'gol_partita',
        'assist_partita',
      });
      expect(json['data_risposta'], '2026-11-21T09:30:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: data costruita nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 21, 9, 45);
      final partecipazione = Partecipazione(
        id: '3c9e5f10-0000-4000-8000-000000000050',
        giocatoreId: '3c9e5f10-0000-4000-8000-000000000002',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        rispostaStato: RispostaStato.confermata,
        dataRisposta: dataLocale,
        golPartita: 0,
        assistPartita: 0,
      );

      final scritta = partecipazione.toJson()['data_risposta'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(
        Partecipazione.fromJson(partecipazione.toJson()).toJson(),
        partecipazione.toJson(),
      );
    });

    test('legge la data con i microsecondi come la restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['data_risposta'] = '2026-11-21T09:30:00.123456+00:00';

      final partecipazione = Partecipazione.fromJson(riga);

      expect(
        partecipazione.dataRisposta,
        DateTime.utc(2026, 11, 21, 9, 30, 0, 123, 456),
      );

      final json = partecipazione.toJson();
      expect(json['data_risposta'], '2026-11-21T09:30:00.123456Z');
      expect(Partecipazione.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test(
      'RispostaStato coincide con la CHECK partecipazione_risposta_stato_check',
      () {
        expect(RispostaStato.valori, {'confermata', 'ritirata'});
        expect(RispostaStato.confermata, 'confermata');
        expect(RispostaStato.ritirata, 'ritirata');
      },
    );
  });
}
