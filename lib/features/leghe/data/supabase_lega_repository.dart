import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/lega.dart';
import '../domain/lega_repository.dart';

/// Implementazione Supabase del repository delle leghe.
///
/// Coordina le tabelle `lega`, `membro_lega` e `amministratore_lega` senza
/// generare dati di business per il codice invito.
class SupabaseLegaRepository implements LegaRepository {
  /// Crea un repository che usa il client Supabase condiviso.
  SupabaseLegaRepository(this._client);

  final SupabaseClient _client;

  /// Esegue una chiamata Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Normalizza un nome come l'indice univoco della migration A.
  String _normalizeName(String name) => name.trim().toLowerCase();

  /// Rimuove l'ID tecnico prima di un insert con UUID generato dal database.
  Map<String, dynamic> _withoutId(Lega lega) {
    final json = lega.toJson()..remove('id');
    return json;
  }

  /// Estrae una Lega da una riga di relazione `lega(*)`.
  Lega _fromRelation(Map<String, dynamic> row) {
    final relation = row['lega'];
    if (relation is Map<String, dynamic>) {
      return Lega.fromJson(relation);
    }
    if (relation is List && relation.isNotEmpty && relation.first is Map) {
      return Lega.fromJson(Map<String, dynamic>.from(relation.first as Map));
    }
    return Lega.fromJson(row);
  }

  /// Restituisce l'errore per il tentativo di rimuovere l'unico amministratore.
  AppException _lastAdminError() {
    return AppException.database(
      message: 'Nomina un altro amministratore prima di uscire.',
      code: '23514',
    );
  }

  /// Verifica se un giocatore è già amministratore della lega.
  Future<bool> _isAdmin(String legaId, String giocatoreId) async {
    final row = await _client
        .from('amministratore_lega')
        .select('giocatore_id')
        .eq('lega_id', legaId)
        .eq('giocatore_id', giocatoreId)
        .maybeSingle();
    return row != null;
  }

  /// Conta gli amministratori della lega.
  Future<int> _adminCount(String legaId) async {
    final rows = await _client
        .from('amministratore_lega')
        .select('giocatore_id')
        .eq('lega_id', legaId);
    return rows.length;
  }

  @override
  Future<Lega> createLega(Lega lega, String adminGiocatoreId) {
    return _execute(() async {
      Lega? created;
      try {
        final row = await _client
            .from('lega')
            .insert(_withoutId(lega))
            .select()
            .single();
        created = Lega.fromJson(row);

        await _client.from('membro_lega').insert({
          'lega_id': created.id,
          'giocatore_id': adminGiocatoreId,
        });
        await _client.from('amministratore_lega').insert({
          'lega_id': created.id,
          'giocatore_id': adminGiocatoreId,
        });
      } catch (error) {
        if (created != null) {
          await _client.from('lega').delete().eq('id', created.id);
        }
        rethrow;
      }
      return created;
    });
  }

  @override
  Future<Lega> updateLega(Lega lega) {
    return _execute(() async {
      final row = await _client
          .from('lega')
          .update(lega.toJson()..remove('id'))
          .eq('id', lega.id)
          .select()
          .single();
      return Lega.fromJson(row);
    });
  }

  @override
  Future<Lega?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('lega')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Lega.fromJson(row);
    });
  }

  @override
  Future<Lega?> findByCodiceInvito(String codiceInvito) {
    return _execute(() async {
      final row = await _client
          .from('lega')
          .select()
          .eq('codice_invito', codiceInvito)
          .maybeSingle();
      return row == null ? null : Lega.fromJson(row);
    });
  }

  @override
  Future<bool> existsByNome(String nome) {
    return _execute(() async {
      final rows = await _client.from('lega').select('nome');
      final normalized = _normalizeName(nome);
      return rows.any(
        (row) => _normalizeName(row['nome'] as String) == normalized,
      );
    });
  }

  @override
  Future<List<Lega>> findByGiocatore(String giocatoreId) {
    return _execute(() async {
      final rows = await _client
          .from('membro_lega')
          .select('lega(*)')
          .eq('giocatore_id', giocatoreId);
      return rows.map<Lega>(_fromRelation).toList();
    });
  }

  @override
  Future<List<Lega>> findPubbliche() {
    return _execute(() async {
      final rows = await _client
          .from('lega')
          .select()
          .eq('privacy', PrivacyLega.pubblica);
      return rows.map<Lega>(Lega.fromJson).toList();
    });
  }

  @override
  Future<void> aggiungiMembro(
    String legaId,
    String giocatoreId, {
    bool isAdmin = false,
  }) {
    return _execute(() async {
      await _client.from('membro_lega').insert({
        'lega_id': legaId,
        'giocatore_id': giocatoreId,
      });
      if (isAdmin) {
        try {
          await _client.from('amministratore_lega').insert({
            'lega_id': legaId,
            'giocatore_id': giocatoreId,
          });
        } catch (error) {
          await _client
              .from('membro_lega')
              .delete()
              .eq('lega_id', legaId)
              .eq('giocatore_id', giocatoreId);
          rethrow;
        }
      }
    });
  }

  @override
  Future<void> rimuoviMembro(String legaId, String giocatoreId) {
    return _execute(() async {
      if (await _isAdmin(legaId, giocatoreId) &&
          await _adminCount(legaId) <= 1) {
        throw _lastAdminError();
      }
      await _client
          .from('amministratore_lega')
          .delete()
          .eq('lega_id', legaId)
          .eq('giocatore_id', giocatoreId);
      await _client
          .from('membro_lega')
          .delete()
          .eq('lega_id', legaId)
          .eq('giocatore_id', giocatoreId);
    });
  }

  @override
  Future<void> promuoviAdAdmin(String legaId, String giocatoreId) {
    return _execute(() async {
      final member = await _client
          .from('membro_lega')
          .select('giocatore_id')
          .eq('lega_id', legaId)
          .eq('giocatore_id', giocatoreId)
          .maybeSingle();
      if (member == null) {
        throw AppException.database(
          message: 'Il giocatore deve essere membro della lega.',
          code: '23503',
        );
      }
      await _client.from('amministratore_lega').insert({
        'lega_id': legaId,
        'giocatore_id': giocatoreId,
      });
    });
  }
}
