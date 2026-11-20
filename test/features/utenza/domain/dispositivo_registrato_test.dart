// Test di serializzazione dell'entity DispositivoRegistrato.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase (date "...+00:00") e le chiavi della migration A.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/domain/dispositivo_registrato.dart';

void main() {
  // Riga fittizia di `dispositivo_registrato` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '7a1d0c3b-0000-4000-8000-000000000010',
    'account_id': '0b6f1c2e-0000-4000-8000-000000000001',
    'identificativo': 'dispositivo-test-1',
    'primo_accesso': '2026-11-01T09:30:00+00:00',
    'ultimo_accesso': '2026-11-20T18:15:45.123+00:00',
  };

  group('DispositivoRegistrato fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final dispositivo = DispositivoRegistrato(
        id: '7a1d0c3b-0000-4000-8000-000000000010',
        accountId: '0b6f1c2e-0000-4000-8000-000000000001',
        identificativo: 'dispositivo-test-1',
        primoAccesso: DateTime.utc(2026, 11, 1, 9, 30),
        ultimoAccesso: DateTime.utc(2026, 11, 20, 18, 15, 45),
      );

      expect(
        DispositivoRegistrato.fromJson(dispositivo.toJson()).toJson(),
        dispositivo.toJson(),
      );
    });

    test('legge una riga di Supabase campo per campo', () {
      final dispositivo = DispositivoRegistrato.fromJson(rigaSupabase());

      expect(dispositivo.id, '7a1d0c3b-0000-4000-8000-000000000010');
      expect(dispositivo.accountId, '0b6f1c2e-0000-4000-8000-000000000001');
      expect(dispositivo.identificativo, 'dispositivo-test-1');
      expect(dispositivo.primoAccesso, DateTime.utc(2026, 11, 1, 9, 30));
      expect(
        dispositivo.ultimoAccesso,
        DateTime.utc(2026, 11, 20, 18, 15, 45, 123),
      );
    });

    test('toJson usa le colonne della migration A e date ISO 8601 UTC', () {
      final json = DispositivoRegistrato.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'account_id',
        'identificativo',
        'primo_accesso',
        'ultimo_accesso',
      });
      expect(json['primo_accesso'], '2026-11-01T09:30:00.000Z');
      expect(json['ultimo_accesso'], '2026-11-20T18:15:45.123Z');
    });

    test('legge date con i microsecondi come le restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['primo_accesso'] = '2026-11-20T18:00:00.123456+00:00'
        ..['ultimo_accesso'] = '2026-11-20T18:30:00.000001+00:00';

      final dispositivo = DispositivoRegistrato.fromJson(riga);

      expect(
        dispositivo.primoAccesso,
        DateTime.utc(2026, 11, 20, 18, 0, 0, 123, 456),
      );
      expect(dispositivo.primoAccesso.microsecond, 456);
      expect(
        dispositivo.ultimoAccesso,
        DateTime.utc(2026, 11, 20, 18, 30, 0, 0, 1),
      );

      final json = dispositivo.toJson();
      expect(json['primo_accesso'], '2026-11-20T18:00:00.123456Z');
      expect(json['ultimo_accesso'], '2026-11-20T18:30:00.000001Z');

      final riletto = DispositivoRegistrato.fromJson(json);
      expect(riletto.primoAccesso, dispositivo.primoAccesso);
      expect(riletto.ultimoAccesso, dispositivo.ultimoAccesso);
      expect(riletto.toJson(), json);
    });
  });
}
