import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/transazione.dart';
import '../domain/transazione_repository.dart';

/// Implementazione Supabase di sola lettura delle transazioni.
///
/// Espone solo query SELECT perche' la tabella viene modificata esclusivamente
/// dalle Edge Functions e dalle revoche RLS C, in conformita' a DG1 e DG2.
class SupabaseTransazioneRepository implements TransazioneRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabaseTransazioneRepository(this._client);

  final SupabaseClient _client;

  /// Esegue una lettura Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  @override
  /// Cerca una transazione tramite la chiave primaria della tabella.
  Future<Transazione?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('transazione')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Transazione.fromJson(row);
    });
  }

  @override
  /// Restituisce tutte le transazioni associate alla quota indicata.
  Future<List<Transazione>> findByQuota(String quotaId) {
    return _execute(() async {
      final rows = await _client
          .from('transazione')
          .select()
          .eq('quota_id', quotaId);
      return rows.map<Transazione>(Transazione.fromJson).toList();
    });
  }

  @override
  /// Restituisce tutte le transazioni associate alla prenotazione indicata.
  Future<List<Transazione>> findByPrenotazione(String prenotazioneId) {
    return _execute(() async {
      final rows = await _client
          .from('transazione')
          .select()
          .eq('prenotazione_id', prenotazioneId);
      return rows.map<Transazione>(Transazione.fromJson).toList();
    });
  }

  @override
  /// Restituisce gli accrediti associati al Gestore del Campo indicato.
  Future<List<Transazione>> findByGestoreCampo(String gestoreCampoId) {
    return _execute(() async {
      final rows = await _client
          .from('transazione')
          .select()
          .eq('gestore_campo_id', gestoreCampoId);
      return rows.map<Transazione>(Transazione.fromJson).toList();
    });
  }

  @override
  /// Cerca la transazione tramite il riferimento esterno univoco.
  Future<Transazione?> findByRiferimentoEsterno(String riferimentoEsterno) {
    return _execute(() async {
      final row = await _client
          .from('transazione')
          .select()
          .eq('riferimento_esterno', riferimentoEsterno)
          .maybeSingle();
      return row == null ? null : Transazione.fromJson(row);
    });
  }
}
