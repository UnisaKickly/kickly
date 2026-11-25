import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/dispositivo_registrato.dart';
import '../domain/dispositivo_repository.dart';

/// Implementazione Supabase del repository dei dispositivi registrati.
///
/// Le date sono serializzate nel formato UTC accettato dalla colonna
/// PostgreSQL `timestamptz`; l'SDK resta confinato allo strato Data.
class SupabaseDispositivoRepository implements DispositivoRepository {
  /// Crea un repository che usa il client Supabase condiviso.
  SupabaseDispositivoRepository(this._client);

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
  Future<DispositivoRegistrato?> findByAccountAndIdentificativo(
    String accountId,
    String identificativo,
  ) {
    return _execute(() async {
      final row = await _client
          .from('dispositivo_registrato')
          .select()
          .eq('account_id', accountId)
          .eq('identificativo', identificativo)
          .maybeSingle();
      return row == null ? null : DispositivoRegistrato.fromJson(row);
    });
  }

  @override
  Future<List<DispositivoRegistrato>> findByAccount(String accountId) {
    return _execute(() async {
      final rows = await _client
          .from('dispositivo_registrato')
          .select()
          .eq('account_id', accountId);
      return rows
          .map<DispositivoRegistrato>(DispositivoRegistrato.fromJson)
          .toList();
    });
  }

  @override
  Future<DispositivoRegistrato> registerDispositivo(
    String accountId,
    DispositivoRegistrato dispositivo,
  ) {
    return _execute(() async {
      final json = dispositivo.toJson()
        ..remove('id')
        ..['account_id'] = accountId;
      final row = await _client
          .from('dispositivo_registrato')
          .insert(json)
          .select()
          .single();
      return DispositivoRegistrato.fromJson(row);
    });
  }

  @override
  Future<void> updateUltimoAccesso(String id, DateTime ultimoAccesso) {
    return _execute(() async {
      await _client
          .from('dispositivo_registrato')
          .update({'ultimo_accesso': ultimoAccesso.toUtc().toIso8601String()})
          .eq('id', id);
    });
  }
}
