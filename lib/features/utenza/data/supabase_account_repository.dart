import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/gestore_campo.dart';
import '../domain/giocatore.dart';

/// Implementazione Supabase del repository degli account.
///
/// Traduce le righe piatte e le righe delle specializzazioni nelle entity
/// del dominio, mantenendo gli SDK confinati nello strato Data.
class SupabaseAccountRepository implements AccountRepository {
  /// Crea un repository che usa il client Supabase condiviso.
  SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  /// Esegue un'operazione Supabase traducendo ogni errore in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Appiattisce la riga Account e la relativa specializzazione.
  Account _fromRow(Map<String, dynamic> row) {
    final giocatore = _specializzazione(row['giocatore']);
    if (giocatore != null) {
      return Giocatore.fromJson({...row, ...giocatore});
    }

    final gestore = _specializzazione(row['gestore_campo']);
    if (gestore != null) {
      return GestoreCampo.fromJson({...row, ...gestore});
    }

    return Account.fromJson(row);
  }

  /// Normalizza la forma restituita da PostgREST per una relazione 0..1.
  Map<String, dynamic>? _specializzazione(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  /// Legge un Account con entrambe le possibili specializzazioni.
  Future<Account?> _findSingle(String column, String value) {
    return _execute(() async {
      final row = await _client
          .from('account')
          .select('*, giocatore(*), gestore_campo(*)')
          .eq(column, value)
          .maybeSingle();
      return row == null ? null : _fromRow(row);
    });
  }

  /// Estrae soltanto le colonne della tabella account.
  Map<String, dynamic> _accountColumns(Account account) {
    final json = account.toJson();
    return {
      'id': json['id'],
      'ruolo_account': json['ruolo_account'],
      'nome': json['nome'],
      'cognome': json['cognome'],
      'email': json['email'],
      'eta': json['eta'],
      'stato_account': json['stato_account'],
      'stato_onboarding': json['stato_onboarding'],
      'preferenze_notifiche': json['preferenze_notifiche'],
    };
  }

  /// Recupera l'entity aggiornata dopo una scrittura.
  Future<T> _requireSpecialized<T extends Account>(String id) async {
    final account = await findById(id);
    if (account is T) {
      return account;
    }
    throw StateError('Specializzazione account non trovata');
  }

  @override
  Future<Account?> findById(String id) => _findSingle('id', id);

  @override
  Future<Account?> findByEmail(String email) => _findSingle('email', email);

  @override
  Future<Account> createAccount(Account account) {
    return _execute(() async {
      final row = await _client
          .from('account')
          .upsert(_accountColumns(account), onConflict: 'id')
          .select('*, giocatore(*), gestore_campo(*)')
          .single();
      return _fromRow(row);
    });
  }

  @override
  Future<Giocatore> completaOnboardingGiocatore(Giocatore giocatore) {
    return _execute(() async {
      await _client
          .from('account')
          .update(_accountColumns(giocatore))
          .eq('id', giocatore.id);
      await _client.from('giocatore').upsert({
        'account_id': giocatore.id,
        'ruolo_preferito_in_campo': giocatore.ruoloPreferitoInCampo,
        'piede_dominante': giocatore.piedeDominante,
      }, onConflict: 'account_id');
      return _requireSpecialized<Giocatore>(giocatore.id);
    });
  }

  @override
  Future<GestoreCampo> completaOnboardingGestore(GestoreCampo gestore) {
    return _execute(() async {
      await _client
          .from('account')
          .update(_accountColumns(gestore))
          .eq('id', gestore.id);
      await _client.from('gestore_campo').upsert({
        'account_id': gestore.id,
        'id_account_pagamenti': gestore.idAccountPagamenti,
      }, onConflict: 'account_id');
      return _requireSpecialized<GestoreCampo>(gestore.id);
    });
  }

  @override
  Future<Giocatore> aggiornaPlayerCard(Giocatore giocatore) {
    return _execute(() async {
      await _client
          .from('giocatore')
          .update({
            'ruolo_preferito_in_campo': giocatore.ruoloPreferitoInCampo,
            'piede_dominante': giocatore.piedeDominante,
          })
          .eq('account_id', giocatore.id);
      return _requireSpecialized<Giocatore>(giocatore.id);
    });
  }

  @override
  Future<void> aggiornaPreferenzeNotifiche(
    String accountId,
    String preferenzeNotifiche,
  ) {
    return _execute(() async {
      await _client
          .from('account')
          .update({'preferenze_notifiche': preferenzeNotifiche})
          .eq('id', accountId);
    });
  }

  @override
  Future<void> aggiornaStatoAccount(String accountId, String statoAccount) {
    return _execute(() async {
      await _client
          .from('account')
          .update({'stato_account': statoAccount})
          .eq('id', accountId);
    });
  }

  @override
  Future<void> deleteAccount(String accountId) {
    return _execute(() async {
      await _client.from('account').delete().eq('id', accountId);
    });
  }
}
