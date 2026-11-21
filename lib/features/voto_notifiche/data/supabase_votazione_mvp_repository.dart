import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/votazione_mvp.dart';
import '../domain/votazione_mvp_repository.dart';

/// Implementazione Supabase delle votazioni MVP e delle preferenze di voto.
///
/// Converte direttamente le righe delle tabelle C nelle entity Dart e usa il
/// client condiviso dalla Persistenza, senza esporre SDK o dettagli tecnici ai
/// livelli superiori.
class SupabaseVotazioneMVPRepository implements VotazioneMVPRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabaseVotazioneMVPRepository(this._client);

  final SupabaseClient _client;

  /// Esegue una chiamata Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  @override
  /// Cerca una votazione tramite la chiave primaria della tabella.
  Future<VotazioneMVP?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('votazione_mvp')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : VotazioneMVP.fromJson(row);
    });
  }

  @override
  /// Cerca la votazione associata alla partita indicata.
  Future<VotazioneMVP?> findByPartita(String partitaId) {
    return _execute(() async {
      final row = await _client
          .from('votazione_mvp')
          .select()
          .eq('partita_id', partitaId)
          .maybeSingle();
      return row == null ? null : VotazioneMVP.fromJson(row);
    });
  }

  @override
  /// Recupera il giocatore votato dall'unica preferenza del votante.
  Future<String?> findPreferenzaVotato(String votazioneId, String votanteId) {
    return _execute(() async {
      final row = await _client
          .from('preferenza_voto_mvp')
          .select('votato_id')
          .eq('votazione_id', votazioneId)
          .eq('votante_id', votanteId)
          .maybeSingle();
      return row == null ? null : row['votato_id'] as String?;
    });
  }

  @override
  /// Inserisce la preferenza rispettando la chiave unica votazione-votante.
  Future<void> registraPreferenza(
    String votazioneId,
    String votanteId,
    String votatoId,
  ) {
    return _execute(() async {
      await _client.from('preferenza_voto_mvp').insert({
        'votazione_id': votazioneId,
        'votante_id': votanteId,
        'votato_id': votatoId,
      });
    });
  }

  @override
  /// Aggiorna il vincitore; in produzione e' destinato all'esecuzione server
  /// perche' la Migration C non concede scritture client sulla votazione.
  Future<void> updateVincitore(String votazioneId, String? vincitoreId) {
    return _execute(() async {
      await _client
          .from('votazione_mvp')
          .update({'vincitore_id': vincitoreId})
          .eq('id', votazioneId);
    });
  }

  @override
  /// Aggiorna lo stato; in produzione e' destinato all'esecuzione server
  /// perche' la Migration C protegge la tabella con le policy RLS C.
  Future<void> updateStato(String votazioneId, String statoVotazione) {
    return _execute(() async {
      await _client
          .from('votazione_mvp')
          .update({'stato_votazione': statoVotazione})
          .eq('id', votazioneId);
    });
  }
}
