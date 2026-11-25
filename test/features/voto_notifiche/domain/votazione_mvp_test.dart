// Test di serializzazione dell'entity VotazioneMVP e di StatoVotazione.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, il vincitore facoltativo, l'assenza delle preferenze
// (le gestisce il repository, regola 6), la conversione in UTC di una data
// locale e i valori ammessi della CHECK della Migration C (D27).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/voto_notifiche/domain/votazione_mvp.dart';

void main() {
  // Riga fittizia di `votazione_mvp` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000060',
    'partita_id': '3c9e5f10-0000-4000-8000-000000000030',
    'stato_votazione': 'chiusa',
    'scadenza': '2026-11-28T20:00:00+00:00',
    'vincitore_id': '3c9e5f10-0000-4000-8000-000000000002',
  };

  group('VotazioneMVP fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final votazione = VotazioneMVP(
        id: '3c9e5f10-0000-4000-8000-000000000060',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        statoVotazione: StatoVotazione.chiusa,
        scadenza: DateTime.utc(2026, 11, 28, 20),
        vincitoreId: '3c9e5f10-0000-4000-8000-000000000002',
      );

      expect(
        VotazioneMVP.fromJson(votazione.toJson()).toJson(),
        votazione.toJson(),
      );
    });

    test('legge una riga di Supabase campo per campo', () {
      final votazione = VotazioneMVP.fromJson(rigaSupabase());

      expect(votazione.id, '3c9e5f10-0000-4000-8000-000000000060');
      expect(votazione.partitaId, '3c9e5f10-0000-4000-8000-000000000030');
      expect(votazione.statoVotazione, 'chiusa');
      expect(votazione.scadenza, DateTime.utc(2026, 11, 28, 20));
      expect(votazione.vincitoreId, '3c9e5f10-0000-4000-8000-000000000002');
    });

    test('votazione aperta senza vincitore: null letto e riscritto', () {
      final riga = rigaSupabase()
        ..['stato_votazione'] = 'aperta'
        ..['vincitore_id'] = null;

      final votazione = VotazioneMVP.fromJson(riga);

      expect(votazione.statoVotazione, 'aperta');
      expect(votazione.vincitoreId, isNull);
      expect(votazione.toJson()['vincitore_id'], isNull);
    });

    test('toJson usa le colonne della Migration C, senza le preferenze', () {
      final json = VotazioneMVP.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'partita_id',
        'stato_votazione',
        'scadenza',
        'vincitore_id',
      });
      expect(json.containsKey('preferenze_votante_votato'), isFalse);
      expect(json['scadenza'], '2026-11-28T20:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: scadenza costruita nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 28, 20, 30);
      final votazione = VotazioneMVP(
        id: '3c9e5f10-0000-4000-8000-000000000060',
        partitaId: '3c9e5f10-0000-4000-8000-000000000030',
        statoVotazione: StatoVotazione.aperta,
        scadenza: dataLocale,
      );

      final scritta = votazione.toJson()['scadenza'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(
        VotazioneMVP.fromJson(votazione.toJson()).toJson(),
        votazione.toJson(),
      );
    });

    test('legge la scadenza con i microsecondi come la restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['scadenza'] = '2026-11-28T20:00:00.123456+00:00';

      final votazione = VotazioneMVP.fromJson(riga);

      expect(
        votazione.scadenza,
        DateTime.utc(2026, 11, 28, 20, 0, 0, 123, 456),
      );

      final json = votazione.toJson();
      expect(json['scadenza'], '2026-11-28T20:00:00.123456Z');
      expect(VotazioneMVP.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test('StatoVotazione coincide con la CHECK votazione_mvp_stato_votazione_check', () {
      expect(StatoVotazione.valori, {'aperta', 'chiusa'});
      expect(StatoVotazione.aperta, 'aperta');
      expect(StatoVotazione.chiusa, 'chiusa');
    });
  });
}
