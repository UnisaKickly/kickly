import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/partita.dart';
import '../domain/partita_repository.dart';

/// Implementazione Supabase del repository delle partite.
///
/// Mantiene nello strato Data la mappatura delle colonne della Migration B
/// e lascia nello strato Domain le sole entity e il relativo contratto.
class SupabasePartitaRepository implements PartitaRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabasePartitaRepository(this._client);

  final SupabaseClient _client;

  /// Esegue un'operazione Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Converte una Partita nelle colonne della tabella `partita`.
  Map<String, dynamic> _columns(Partita partita) => {
    'giocatore_id': partita.giocatoreId,
    'lega_id': partita.legaId,
    'data_ora': partita.dataOra.toUtc().toIso8601String(),
    'tipologia': partita.tipologia,
    'privacy': partita.privacy,
    'num_partecipanti_richiesti': partita.numPartecipantiRichiesti,
    'stato': partita.stato,
    'link_condivisione': partita.linkCondivisione,
  };

  @override
  /// Recupera la Partita corrispondente alla chiave indicata.
  Future<Partita?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('partita')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Partita.fromJson(row);
    });
  }

  @override
  /// Restituisce le partite pubbliche senza appartenenza a una Lega.
  Future<List<Partita>> findPubbliche() {
    return _execute(() async {
      final rows = await _client
          .from('partita')
          .select()
          .eq('privacy', PrivacyPartita.pubblica);
      return rows
          .where((row) => row['lega_id'] == null)
          .map<Partita>(Partita.fromJson)
          .toList();
    });
  }

  @override
  /// Restituisce le partite organizzate dal Giocatore indicato.
  Future<List<Partita>> findByGiocatore(String giocatoreId) {
    return _execute(() async {
      final rows = await _client
          .from('partita')
          .select()
          .eq('giocatore_id', giocatoreId);
      return rows.map<Partita>(Partita.fromJson).toList();
    });
  }

  @override
  /// Restituisce le partite appartenenti alla Lega indicata.
  Future<List<Partita>> findByLega(String legaId) {
    return _execute(() async {
      final rows = await _client.from('partita').select().eq('lega_id', legaId);
      return rows.map<Partita>(Partita.fromJson).toList();
    });
  }

  @override
  /// Inserisce una nuova Partita senza inviare l'identificativo tecnico.
  Future<Partita> createPartita(Partita partita) {
    return _execute(() async {
      final row = await _client
          .from('partita')
          .insert(_columns(partita))
          .select()
          .single();
      return Partita.fromJson(row);
    });
  }

  @override
  /// Aggiorna la Partita esistente scrivendo solo la colonna `stato`.
  ///
  /// Dopo KCK-226 il GRANT per colonna ammette dal client solo `stato`, e il
  /// trigger `partita_cambio_stato_consentito` solo l'annullamento da parte
  /// dell'organizzatore: mandare le altre colonne produrrebbe un 42501
  /// (decisione dei PM). Gli altri dati restano quelli persistiti.
  Future<Partita> updatePartita(Partita partita) {
    return _execute(() async {
      final row = await _client
          .from('partita')
          .update({'stato': partita.stato})
          .eq('id', partita.id)
          .select()
          .single();
      return Partita.fromJson(row);
    });
  }

  @override
  /// Aggiorna lo stato della Partita senza applicare transizioni nel repository.
  Future<void> updateStato(String id, String stato) {
    return _execute(() async {
      await _client.from('partita').update({'stato': stato}).eq('id', id);
    });
  }

  @override
  /// Elimina la Partita corrispondente alla chiave indicata.
  Future<void> deletePartita(String id) {
    return _execute(() async {
      await _client.from('partita').delete().eq('id', id);
    });
  }
}
