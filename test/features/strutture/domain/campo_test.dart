// Test di serializzazione dell'entity Campo.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, la tariffa letta sia da intero sia da decimale e le
// chiavi della regola 9 (gestore_campo_id).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/strutture/domain/campo.dart';

void main() {
  // Riga fittizia di `campo` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '5d2e7a90-0000-4000-8000-000000000030',
    'gestore_campo_id': '20200000-0000-4000-8000-000000000004',
    'nome': 'Campo A',
    'ubicazione': 'Via dello Sport 1, Salerno',
    'tariffa_oraria': 60.5,
    'orari_disponibilita': '2026-11-20T18:00/2026-11-20T19:00',
  };

  group('Campo fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      const campo = Campo(
        id: '5d2e7a90-0000-4000-8000-000000000030',
        gestoreCampoId: '20200000-0000-4000-8000-000000000004',
        nome: 'Campo A',
        ubicazione: 'Via dello Sport 1, Salerno',
        tariffaOraria: 60.5,
        orariDisponibilita: '2026-11-20T18:00/2026-11-20T19:00',
      );

      expect(Campo.fromJson(campo.toJson()).toJson(), campo.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final campo = Campo.fromJson(rigaSupabase());

      expect(campo.id, '5d2e7a90-0000-4000-8000-000000000030');
      expect(campo.gestoreCampoId, '20200000-0000-4000-8000-000000000004');
      expect(campo.nome, 'Campo A');
      expect(campo.ubicazione, 'Via dello Sport 1, Salerno');
      expect(campo.tariffaOraria, 60.5);
      expect(campo.orariDisponibilita, '2026-11-20T18:00/2026-11-20T19:00');
    });

    test('tariffa senza decimali: letta come double', () {
      // Preparazione: PostgreSQL restituisce 60 per una tariffa intera.
      final riga = rigaSupabase()..['tariffa_oraria'] = 60;

      final campo = Campo.fromJson(riga);

      expect(campo.tariffaOraria, isA<double>());
      expect(campo.tariffaOraria, 60.0);
    });

    test('toJson usa le colonne della regola 9, con gestore_campo_id', () {
      final json = Campo.fromJson(rigaSupabase()).toJson();

      expect(json, rigaSupabase());
      expect(json.keys.toSet(), {
        'id',
        'gestore_campo_id',
        'nome',
        'ubicazione',
        'tariffa_oraria',
        'orari_disponibilita',
      });
    });
  });
}
