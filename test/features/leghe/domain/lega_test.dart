// Test di serializzazione dell'entity Lega e delle sue costanti.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase (date "...+00:00"), il codice di invito facoltativo e
// i valori ammessi delle CHECK della migration A.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  // Riga fittizia di `lega` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '3c9e5f10-0000-4000-8000-000000000020',
    'nome': 'Lega del Giovedi',
    'tipologia_match': '5v5',
    'privacy': 'privata',
    'codice_invito': 'INVITO-TEST',
    'scadenza_codice_invito': '2026-11-27T20:00:00+00:00',
  };

  group('Lega fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      final lega = Lega(
        id: '3c9e5f10-0000-4000-8000-000000000020',
        nome: 'Lega del Giovedi',
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        codiceInvito: 'INVITO-TEST',
        scadenzaCodiceInvito: DateTime.utc(2026, 11, 27, 20),
      );

      expect(Lega.fromJson(lega.toJson()).toJson(), lega.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final lega = Lega.fromJson(rigaSupabase());

      expect(lega.id, '3c9e5f10-0000-4000-8000-000000000020');
      expect(lega.nome, 'Lega del Giovedi');
      expect(lega.tipologiaMatch, '5v5');
      expect(lega.privacy, 'privata');
      expect(lega.codiceInvito, 'INVITO-TEST');
      expect(lega.scadenzaCodiceInvito, DateTime.utc(2026, 11, 27, 20));
    });

    test('codice di invito non generato: null letti e riscritti', () {
      final riga = rigaSupabase()
        ..['privacy'] = 'pubblica'
        ..['codice_invito'] = null
        ..['scadenza_codice_invito'] = null;

      final lega = Lega.fromJson(riga);

      expect(lega.codiceInvito, isNull);
      expect(lega.scadenzaCodiceInvito, isNull);
      expect(lega.toJson()['codice_invito'], isNull);
      expect(lega.toJson()['scadenza_codice_invito'], isNull);
    });

    test('toJson usa le colonne della migration A, senza membri ne\' amministratori', () {
      final json = Lega.fromJson(rigaSupabase()).toJson();

      expect(json.keys.toSet(), {
        'id',
        'nome',
        'tipologia_match',
        'privacy',
        'codice_invito',
        'scadenza_codice_invito',
      });
      expect(json['scadenza_codice_invito'], '2026-11-27T20:00:00.000Z');
    });

    test('legge la scadenza con i microsecondi come la restituisce PostgREST', () {
      // Preparazione: timestamptz con sei cifre decimali, formato di PostgREST.
      // Esito atteso: i microsecondi sono conservati in lettura e nel round-trip.
      final riga = rigaSupabase()
        ..['scadenza_codice_invito'] = '2026-11-20T18:00:00.123456+00:00';

      final lega = Lega.fromJson(riga);

      expect(
        lega.scadenzaCodiceInvito,
        DateTime.utc(2026, 11, 20, 18, 0, 0, 123, 456),
      );
      expect(lega.scadenzaCodiceInvito!.microsecond, 456);

      final json = lega.toJson();
      expect(json['scadenza_codice_invito'], '2026-11-20T18:00:00.123456Z');

      final riletta = Lega.fromJson(json);
      expect(riletta.scadenzaCodiceInvito, lega.scadenzaCodiceInvito);
      expect(riletta.toJson(), json);
    });
  });

  group('valori ammessi', () {
    test('TipologiaMatch coincide con la CHECK lega_tipologia_match_check', () {
      expect(TipologiaMatch.valori, {
        '5v5',
        '6v6',
        '7v7',
        '8v8',
        '9v9',
        '10v10',
        '11v11',
      });
      expect(TipologiaMatch.cinqueVsCinque, '5v5');
      expect(TipologiaMatch.seiVsSei, '6v6');
      expect(TipologiaMatch.setteVsSette, '7v7');
      expect(TipologiaMatch.ottoVsOtto, '8v8');
      expect(TipologiaMatch.noveVsNove, '9v9');
      expect(TipologiaMatch.dieciVsDieci, '10v10');
      expect(TipologiaMatch.undiciVsUndici, '11v11');
    });

    test('PrivacyLega coincide con la CHECK lega_privacy_check', () {
      expect(PrivacyLega.valori, {'pubblica', 'privata'});
      expect(PrivacyLega.pubblica, 'pubblica');
      expect(PrivacyLega.privata, 'privata');
    });
  });
}
