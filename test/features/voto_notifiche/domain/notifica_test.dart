// Test di serializzazione dell'entity Notifica e di TipoNotifica.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, lo stato di lettura, la conversione in UTC di una
// data locale e i valori ammessi della CHECK della Migration C (D27).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/voto_notifiche/domain/notifica.dart';

void main() {
  // Riga fittizia di `notifica` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000070',
    'account_id': '3c9e5f10-0000-4000-8000-000000000002',
    'tipo': 'partita_confermata',
    'messaggio': 'La partita del giovedi e\' confermata',
    'stato_lettura': false,
    'timestamp': '2026-11-21T10:00:00+00:00',
  };

  group('Notifica fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final notifica = Notifica(
        id: '3c9e5f10-0000-4000-8000-000000000070',
        accountId: '3c9e5f10-0000-4000-8000-000000000002',
        tipo: TipoNotifica.partitaConfermata,
        messaggio: 'La partita del giovedi e\' confermata',
        statoLettura: false,
        timestamp: DateTime.utc(2026, 11, 21, 10),
      );

      expect(Notifica.fromJson(notifica.toJson()).toJson(), notifica.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final notifica = Notifica.fromJson(rigaSupabase());

      expect(notifica.id, '3c9e5f10-0000-4000-8000-000000000070');
      expect(notifica.accountId, '3c9e5f10-0000-4000-8000-000000000002');
      expect(notifica.tipo, 'partita_confermata');
      expect(notifica.messaggio, 'La partita del giovedi e\' confermata');
      expect(notifica.statoLettura, isFalse);
      expect(notifica.timestamp, DateTime.utc(2026, 11, 21, 10));
    });

    test('notifica letta: stato_lettura true letto e riscritto', () {
      final riga = rigaSupabase()..['stato_lettura'] = true;

      final notifica = Notifica.fromJson(riga);

      expect(notifica.statoLettura, isTrue);
      expect(notifica.toJson()['stato_lettura'], isTrue);
    });

    test('toJson usa le colonne della Migration C', () {
      final json = Notifica.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'account_id',
        'tipo',
        'messaggio',
        'stato_lettura',
        'timestamp',
      });
      expect(json['stato_lettura'], isFalse);
      expect(json['timestamp'], '2026-11-21T10:00:00.000Z');
    });

    test('data locale: toJson la scrive in UTC allo stesso istante', () {
      // Preparazione: timestamp costruito nel fuso locale, non con DateTime.utc.
      // Esito atteso: stringa in UTC (finale 'Z') che indica lo stesso istante.
      final dataLocale = DateTime(2026, 11, 21, 10, 15);
      final notifica = Notifica(
        id: '3c9e5f10-0000-4000-8000-000000000070',
        accountId: '3c9e5f10-0000-4000-8000-000000000002',
        tipo: TipoNotifica.aperturaConvocazioni,
        messaggio: 'Sono aperte le convocazioni',
        statoLettura: false,
        timestamp: dataLocale,
      );

      final scritta = notifica.toJson()['timestamp'] as String;

      expect(scritta, endsWith('Z'));
      expect(DateTime.parse(scritta).isAtSameMomentAs(dataLocale), isTrue);
      expect(Notifica.fromJson(notifica.toJson()).toJson(), notifica.toJson());
    });

    test('legge il timestamp con i microsecondi come lo restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['timestamp'] = '2026-11-21T10:00:00.123456+00:00';

      final notifica = Notifica.fromJson(riga);

      expect(
        notifica.timestamp,
        DateTime.utc(2026, 11, 21, 10, 0, 0, 123, 456),
      );

      final json = notifica.toJson();
      expect(json['timestamp'], '2026-11-21T10:00:00.123456Z');
      expect(Notifica.fromJson(json).toJson(), json);
    });
  });

  group('valori ammessi', () {
    test('TipoNotifica coincide con la CHECK notifica_tipo_check', () {
      expect(TipoNotifica.valori, {
        'apertura_sondaggio_mvp',
        'apertura_convocazioni',
        'partita_confermata',
      });
      expect(TipoNotifica.aperturaSondaggioMVP, 'apertura_sondaggio_mvp');
      expect(TipoNotifica.aperturaConvocazioni, 'apertura_convocazioni');
      expect(TipoNotifica.partitaConfermata, 'partita_confermata');
    });
  });
}
