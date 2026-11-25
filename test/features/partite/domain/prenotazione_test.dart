// Test di serializzazione dell'entity Prenotazione e di StatoBlocco.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, la scadenza facoltativa, gli importi interi letti
// come double, la conversione in UTC di una data locale e i valori ammessi
// della CHECK della migration B (D24).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/partite/domain/prenotazione.dart';

void main() {
  // Riga fittizia di `prenotazione` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000040',
    'partita_id': '3c9e5f10-0000-4000-8000-000000000030',
    'campo_id': '3c9e5f10-0000-4000-8000-000000000010',
    'intervallo': '2026-11-27T20:00/2026-11-27T21:00',
    'stato_blocco': 'bloccato',
    'scadenza_blocco': '2026-11-26T20:00:00+00:00',
    'costo_concordato': 60.0,
    'quota_individuale': 6.5,
    'commissione': 5.0,
    'netto_gestore': 55.0,
  };

  group('Prenotazione fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final prenotazione = Prenotazione(
        id: '3c9e5f10-0000-4000-8000-000000000040',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        campoId: '3c9e5f10-0000-4000-8000-000000000010',
        intervallo: '2026-11-27T20:00/2026-11-27T21:00',
        statoBlocco: StatoBlocco.bloccato,
        scadenzaBlocco: DateTime.utc(2026, 11, 26, 20),
        costoConcordato: 60,
        quotaIndividuale: 6.5,
        commissione: 5,
        nettoGestore: 55,
      );

      expect(
        Prenotazione.fromJson(prenotazione.toJson()).toJson(),
        prenotazione.toJson(),
      );
    });

    test('legge una riga di Supabase campo per campo', () {
      final prenotazione = Prenotazione.fromJson(rigaSupabase());

      expect(prenotazione.id, '3c9e5f10-0000-4000-8000-000000000040');
      expect(prenotazione.partitaId, '3c9e5f10-0000-4000-8000-000000000030');
      expect(prenotazione.campoId, '3c9e5f10-0000-4000-8000-000000000010');
      expect(prenotazione.intervallo, '2026-11-27T20:00/2026-11-27T21:00');
      expect(prenotazione.statoBlocco, 'bloccato');
      expect(prenotazione.scadenzaBlocco, DateTime.utc(2026, 11, 26, 20));
      expect(prenotazione.costoConcordato, 60.0);
      expect(prenotazione.quotaIndividuale, 6.5);
      expect(prenotazione.commissione, 5.0);
      expect(prenotazione.nettoGestore, 55.0);
    });

    test('slot liberato senza scadenza: null letto e riscritto', () {
      final riga = rigaSupabase()
        ..['stato_blocco'] = 'liberato'
        ..['scadenza_blocco'] = null;

      final prenotazione = Prenotazione.fromJson(riga);

      expect(prenotazione.scadenzaBlocco, isNull);
      expect(prenotazione.toJson()['scadenza_blocco'], isNull);
    });

    test('importi interi letti come double', () {
      // Preparazione: PostgREST puo' restituire un numeric senza decimali.
      final riga = rigaSupabase()
        ..['costo_concordato'] = 60
        ..['quota_individuale'] = 6
        ..['commissione'] = 5
        ..['netto_gestore'] = 55;

      final prenotazione = Prenotazione.fromJson(riga);

      expect(prenotazione.costoConcordato, isA<double>());
      expect(prenotazione.costoConcordato, 60.0);
      expect(prenotazione.quotaIndividuale, isA<double>());
      expect(prenotazione.quotaIndividuale, 6.0);
      expect(prenotazione.commissione, isA<double>());
      expect(prenotazione.commissione, 5.0);
      expect(prenotazione.nettoGestore, isA<double>());
      expect(prenotazione.nettoGestore, 55.0);
    });

    test('toJson usa le colonne della migration B', () {
      final json = Prenotazione.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'partita_id',
        'campo_id',
        'intervallo',
        'stato_blocco',
        'scadenza_blocco',
        'costo_concordato',
        'quota_individuale',
        'commissione',
        'netto_gestore',
      });
      expect(json['scadenza_blocco'], '2026-11-26T20:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: scadenza costruita nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 26, 20, 15);
      final prenotazione = Prenotazione(
        id: '3c9e5f10-0000-4000-8000-000000000040',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        campoId: '3c9e5f10-0000-4000-8000-000000000010',
        intervallo: '2026-11-27T20:00/2026-11-27T21:00',
        statoBlocco: StatoBlocco.bloccato,
        scadenzaBlocco: dataLocale,
        costoConcordato: 60,
        quotaIndividuale: 6.5,
        commissione: 5,
        nettoGestore: 55,
      );

      final scritta = prenotazione.toJson()['scadenza_blocco'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(
        Prenotazione.fromJson(prenotazione.toJson()).toJson(),
        prenotazione.toJson(),
      );
    });

    test('legge la scadenza con i microsecondi come la restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['scadenza_blocco'] = '2026-11-26T20:00:00.123456+00:00';

      final prenotazione = Prenotazione.fromJson(riga);

      expect(
        prenotazione.scadenzaBlocco,
        DateTime.utc(2026, 11, 26, 20, 0, 0, 123, 456),
      );

      final json = prenotazione.toJson();
      expect(json['scadenza_blocco'], '2026-11-26T20:00:00.123456Z');
      expect(Prenotazione.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test(
      'StatoBlocco coincide con la CHECK prenotazione_stato_blocco_check',
      () {
        expect(StatoBlocco.valori, {'bloccato', 'confermato', 'liberato'});
        expect(StatoBlocco.bloccato, 'bloccato');
        expect(StatoBlocco.confermato, 'confermato');
        expect(StatoBlocco.liberato, 'liberato');
      },
    );
  });
}
