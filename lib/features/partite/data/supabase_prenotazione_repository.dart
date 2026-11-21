import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/prenotazione.dart';
import '../domain/prenotazione_repository.dart';

/// Implementazione Supabase del repository delle prenotazioni.
///
/// Delegando al database i vincoli sugli intervalli, garantisce che slot
/// sovrapposti e doppie prenotazioni non siano persistibili.
class SupabasePrenotazioneRepository implements PrenotazioneRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabasePrenotazioneRepository(this._client);

  final SupabaseClient _client;

  /// Esegue un'operazione Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Converte una Prenotazione nelle colonne della Migration B.
  Map<String, dynamic> _columns(Prenotazione prenotazione) => {
    'partita_id': prenotazione.partitaId,
    'campo_id': prenotazione.campoId,
    'intervallo': prenotazione.intervallo,
    'stato_blocco': prenotazione.statoBlocco,
    'scadenza_blocco': prenotazione.scadenzaBlocco?.toUtc().toIso8601String(),
    'costo_concordato': prenotazione.costoConcordato,
    'quota_individuale': prenotazione.quotaIndividuale,
    'commissione': prenotazione.commissione,
    'netto_gestore': prenotazione.nettoGestore,
  };

  @override
  /// Recupera la Prenotazione corrispondente alla chiave indicata.
  Future<Prenotazione?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('prenotazione')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Prenotazione.fromJson(row);
    });
  }

  @override
  /// Restituisce la Prenotazione associata alla Partita indicata.
  Future<Prenotazione?> findByPartita(String partitaId) {
    return _execute(() async {
      final row = await _client
          .from('prenotazione')
          .select()
          .eq('partita_id', partitaId)
          .maybeSingle();
      return row == null ? null : Prenotazione.fromJson(row);
    });
  }

  @override
  /// Restituisce le Prenotazioni relative al Campo indicato.
  Future<List<Prenotazione>> findByCampo(String campoId) {
    return _execute(() async {
      final rows = await _client
          .from('prenotazione')
          .select()
          .eq('campo_id', campoId);
      return rows.map<Prenotazione>(Prenotazione.fromJson).toList();
    });
  }

  @override
  /// Inserisce una nuova Prenotazione assegnandone l'identificativo al database.
  Future<Prenotazione> createPrenotazione(Prenotazione prenotazione) {
    return _execute(() async {
      final row = await _client
          .from('prenotazione')
          .insert(_columns(prenotazione))
          .select()
          .single();
      return Prenotazione.fromJson(row);
    });
  }

  @override
  /// Aggiorna tutti i dati persistiti della Prenotazione esistente.
  Future<Prenotazione> updatePrenotazione(Prenotazione prenotazione) {
    return _execute(() async {
      final row = await _client
          .from('prenotazione')
          .update(_columns(prenotazione))
          .eq('id', prenotazione.id)
          .select()
          .single();
      return Prenotazione.fromJson(row);
    });
  }

  @override
  /// Aggiorna lo stato del blocco e, se presente, la relativa scadenza.
  Future<Prenotazione> updateStatoBlocco(
    String id,
    String statoBlocco,
    DateTime? scadenzaBlocco,
  ) {
    return _execute(() async {
      final row = await _client
          .from('prenotazione')
          .update({
            'stato_blocco': statoBlocco,
            'scadenza_blocco': scadenzaBlocco?.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();
      return Prenotazione.fromJson(row);
    });
  }

  @override
  /// Elimina la Prenotazione corrispondente alla chiave indicata.
  Future<void> deletePrenotazione(String id) {
    return _execute(() async {
      await _client.from('prenotazione').delete().eq('id', id);
    });
  }
}
