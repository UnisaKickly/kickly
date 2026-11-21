// Test di serializzazione dell'entity Quota e di StatoVersamento.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, l'importo intero letto come double, la conversione
// in UTC di una data locale e i valori ammessi della CHECK della
// Migration C (D25).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/pagamenti/domain/quota.dart';

void main() {
  // Riga fittizia di `quota` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000080',
    'partecipazione_id': '3c9e5f10-0000-4000-8000-000000000050',
    'importo': 6.5,
    'stato_versamento': 'da_versare',
    'termine_versamento': '2026-11-26T20:00:00+00:00',
  };

  group('Quota fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final quota = Quota(
        id: '3c9e5f10-0000-4000-8000-000000000080',
        partecipazioneId: '3c9e5f10-0000-4000-8000-000000000050',
        importo: 6.5,
        statoVersamento: StatoVersamento.daVersare,
        termineVersamento: DateTime.utc(2026, 11, 26, 20),
      );

      expect(Quota.fromJson(quota.toJson()).toJson(), quota.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final quota = Quota.fromJson(rigaSupabase());

      expect(quota.id, '3c9e5f10-0000-4000-8000-000000000080');
      expect(quota.partecipazioneId, '3c9e5f10-0000-4000-8000-000000000050');
      expect(quota.importo, 6.5);
      expect(quota.statoVersamento, 'da_versare');
      expect(quota.termineVersamento, DateTime.utc(2026, 11, 26, 20));
    });

    test('importo intero letto come double', () {
      // Preparazione: PostgREST puo' restituire un numeric senza decimali.
      final riga = rigaSupabase()..['importo'] = 6;

      final quota = Quota.fromJson(riga);

      expect(quota.importo, isA<double>());
      expect(quota.importo, 6.0);
    });

    test('toJson usa le colonne della Migration C', () {
      final json = Quota.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'partecipazione_id',
        'importo',
        'stato_versamento',
        'termine_versamento',
      });
      expect(json['termine_versamento'], '2026-11-26T20:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: termine costruito nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 26, 20, 45);
      final quota = Quota(
        id: '3c9e5f10-0000-4000-8000-000000000080',
        partecipazioneId: '3c9e5f10-0000-4000-8000-000000000050',
        importo: 6.5,
        statoVersamento: StatoVersamento.versata,
        termineVersamento: dataLocale,
      );

      final scritta = quota.toJson()['termine_versamento'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(Quota.fromJson(quota.toJson()).toJson(), quota.toJson());
    });

    test('legge il termine con i microsecondi come lo restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['termine_versamento'] = '2026-11-26T20:00:00.123456+00:00';

      final quota = Quota.fromJson(riga);

      expect(
        quota.termineVersamento,
        DateTime.utc(2026, 11, 26, 20, 0, 0, 123, 456),
      );

      final json = quota.toJson();
      expect(json['termine_versamento'], '2026-11-26T20:00:00.123456Z');
      expect(Quota.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test(
      'StatoVersamento coincide con la CHECK quota_stato_versamento_check',
      () {
        expect(StatoVersamento.valori, {'da_versare', 'versata', 'rimborsata'});
        expect(StatoVersamento.daVersare, 'da_versare');
        expect(StatoVersamento.versata, 'versata');
        expect(StatoVersamento.rimborsata, 'rimborsata');
      },
    );
  });
}
