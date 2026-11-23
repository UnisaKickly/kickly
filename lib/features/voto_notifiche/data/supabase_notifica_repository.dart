import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/notifica.dart';
import '../domain/notifica_repository.dart';

/// Implementazione Supabase del repository delle notifiche.
///
/// Legge le notifiche dall'applicazione e consente il solo aggiornamento dello
/// stato di lettura; la creazione resta alle procedure server e a FCM.
class SupabaseNotificaRepository implements NotificaRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabaseNotificaRepository(this._client);

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
  /// Cerca una notifica tramite la chiave primaria della tabella.
  Future<Notifica?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('notifica')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Notifica.fromJson(row);
    });
  }

  @override
  /// Restituisce tutte le notifiche dell'Account indicato.
  Future<List<Notifica>> findByAccount(String accountId) {
    return _execute(() async {
      final rows = await _client
          .from('notifica')
          .select()
          .eq('account_id', accountId);
      return rows.map<Notifica>(Notifica.fromJson).toList();
    });
  }

  @override
  /// Restituisce le sole notifiche non lette dell'Account indicato.
  Future<List<Notifica>> findNonLetteByAccount(String accountId) {
    return _execute(() async {
      final rows = await _client
          .from('notifica')
          .select()
          .eq('account_id', accountId)
          .eq('stato_lettura', false);
      return rows.map<Notifica>(Notifica.fromJson).toList();
    });
  }

  @override
  /// Aggiorna la colonna stato_lettura rispettando la policy RLS dell'owner.
  Future<void> updateStatoLettura(String id, bool statoLettura) {
    return _execute(() async {
      await _client
          .from('notifica')
          .update({'stato_lettura': statoLettura})
          .eq('id', id);
    });
  }
}
