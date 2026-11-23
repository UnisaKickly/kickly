import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
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

  /// Colonne dei dati comuni che il client puo' scrivere su `account`.
  ///
  /// Il GRANT per colonna della RLS (KCK-226) esclude `id`, `email` e
  /// `stato_account`: l'id e l'email li fissa Supabase Auth, lo stato
  /// dell'account cambia solo con la cancellazione (KCK-204). Mandarli
  /// produrrebbe un 42501.
  Map<String, dynamic> _colonneDatiComuni(Account account) {
    final json = account.toJson();
    return {
      'nome': json['nome'],
      'cognome': json['cognome'],
      'eta': json['eta'],
      'preferenze_notifiche': json['preferenze_notifiche'],
    };
  }

  /// Colonne del primo passo dell'onboarding: dati comuni e ruolo scelto.
  ///
  /// `stato_onboarding` resta fuori: va scritto solo dopo la specializzazione,
  /// altrimenti il controllo differito `verifica_onboarding_completato`
  /// rifiuterebbe la transazione (D11).
  Map<String, dynamic> _colonneProfiloAccount(Account account) {
    return {
      ..._colonneDatiComuni(account),
      'ruolo_account': account.toJson()['ruolo_account'],
    };
  }

  /// Aggiorna le colonne dell'account che il GRANT ammette.
  Future<void> _aggiornaAccount(String id, Map<String, dynamic> colonne) {
    return _client.from('account').update(colonne).eq('id', id);
  }

  /// Dice se esiste gia' la riga di specializzazione dell'account.
  ///
  /// Serve alla ripresa di un onboarding interrotto (UC_ACC_1 E3): ogni
  /// chiamata PostgREST e' una transazione a se', quindi la specializzazione
  /// puo' essere stata creata in un tentativo precedente fallito dopo.
  Future<bool> _specializzazioneEsiste(String tabella, String id) async {
    final row = await _client
        .from(tabella)
        .select('account_id')
        .eq('account_id', id)
        .maybeSingle();
    return row != null;
  }

  /// Scrive le colonne della Player Card ammesse dal GRANT su `giocatore`.
  Future<void> _aggiornaColonnePlayerCard(Giocatore giocatore) {
    return _client
        .from('giocatore')
        .update({
          'ruolo_preferito_in_campo': giocatore.ruoloPreferitoInCampo,
          'piede_dominante': giocatore.piedeDominante,
        })
        .eq('account_id', giocatore.id);
  }

  /// Recupera l'entity aggiornata dopo una scrittura.
  Future<T> _requireSpecialized<T extends Account>(String id) async {
    final account = await findById(id);
    if (account is T) {
      return account;
    }
    throw AppException.unexpected(
      originalError: StateError(
        'Specializzazione account non trovata per l\'account $id.',
      ),
    );
  }

  @override
  Future<String> accedi(String email, String password) async {
    try {
      final AuthResponse risposta = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final String? id = risposta.user?.id;
      if (id == null) {
        // Supabase Auth ha risposto senza utente: non e' un rifiuto delle
        // credenziali, quindi non si mostra "Email o password non corretti".
        throw AppException.unexpected(
          originalError: StateError('Login senza utente nella risposta.'),
        );
      }
      return id;
    } on AuthRetryableFetchException catch (error, stackTrace) {
      // Il client Auth segnala cosi' i problemi di rete o del servizio: e'
      // una sottoclasse di AuthException, ma non un rifiuto delle credenziali.
      throw AppException.network(originalError: error, stackTrace: stackTrace);
    } on AuthException catch (error, stackTrace) {
      // Solo il rifiuto delle credenziali (email non registrata o password
      // errata: Supabase Auth risponde con lo stesso `invalid_credentials`)
      // diventa questo codice, cosi' il Control mostra un unico messaggio e
      // non rivela quali email sono registrate (D16). Rate limit, errori del
      // servizio o altri rifiuti seguono la traduzione comune.
      if (!_credenzialiRifiutate(error)) {
        throw translateSupabaseError(error, stackTrace: stackTrace);
      }
      throw AppException(
        message: 'Email o password non corretti',
        code: AccountRepository.codiceCredenzialiNonValide,
        originalError: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> esci() => _execute(() => _client.auth.signOut());

  @override
  String? idAccountAutenticato() => _client.auth.currentUser?.id;

  @override
  Stream<String?> cambiamentiAutenticazione() {
    // Ogni evento di Supabase Auth (signedIn, signedOut, tokenRefreshed...)
    // si riduce all'id dell'utente della sessione, o null senza sessione.
    // Gli errori dell'SDK sullo stream (es. rinnovo del token fallito) si
    // traducono in AppException (DG9); distinct evita di riemettere lo
    // stesso id a ogni rinnovo del token.
    return _client.auth.onAuthStateChange
        .map((AuthState stato) => stato.session?.user.id)
        .transform(
          StreamTransformer<String?, String?>.fromHandlers(
            handleError: (Object error, StackTrace stackTrace, sink) =>
                sink.addError(
                  translateSupabaseError(error, stackTrace: stackTrace),
                  stackTrace,
                ),
          ),
        )
        .distinct();
  }

  /// Dice se Supabase Auth ha rifiutato email e password.
  ///
  /// Supabase Auth risponde 400 con codice `invalid_credentials`; le versioni
  /// che non mandano il codice usano solo lo stato 400.
  bool _credenzialiRifiutate(AuthException error) {
    if (error.code != null) {
      return error.code == 'invalid_credentials';
    }
    return error.statusCode == '400';
  }

  @override
  Future<Account?> findById(String id) => _findSingle('id', id);

  @override
  Future<Account?> findByEmail(String email) => _findSingle('email', email);

  /// Salva i dati comuni sulla riga creata dal trigger e la restituisce.
  ///
  /// La riga di `account` la crea il trigger `crea_account_per_nuovo_utente`
  /// alla registrazione in Supabase Auth: il client non ha INSERT su
  /// `account` (decisione dei PM su KCK-226), quindi qui si aggiornano solo
  /// le colonne con GRANT e si rilegge la riga con le specializzazioni. Se
  /// l'UPDATE non tocca righe, il trigger non ha creato l'account (o non e'
  /// dell'utente autenticato): e' un errore imprevisto, non un dato da creare.
  @override
  Future<Account> createAccount(Account account) {
    return _execute(() async {
      final rows = await _client
          .from('account')
          .update(_colonneDatiComuni(account))
          .eq('id', account.id)
          .select('*, giocatore(*), gestore_campo(*)');
      if (rows.isEmpty) {
        throw AppException.unexpected(
          originalError: StateError(
            'Riga account ${account.id} non creata dal trigger di registrazione.',
          ),
        );
      }
      return _fromRow(rows.first);
    });
  }

  /// Completa l'onboarding del Giocatore in tre passi ordinati.
  ///
  /// Ogni chiamata PostgREST e' una transazione a se' e il database impone
  /// l'ordine (KCK-226, D11): (a) UPDATE di dati comuni e `ruolo_account`,
  /// perche' l'INSERT in `giocatore` richiede gia' il ruolo Giocatore;
  /// (b) INSERT della Player Card, oppure, se esiste gia' per un onboarding
  /// interrotto (UC_ACC_1 E3), UPDATE delle sue colonne; (c) UPDATE di
  /// `stato_onboarding`, che a 'completato' richiede la specializzazione.
  /// Se un passo fallisce i successivi non partono.
  @override
  Future<Giocatore> completaOnboardingGiocatore(Giocatore giocatore) {
    return _execute(() async {
      await _aggiornaAccount(giocatore.id, _colonneProfiloAccount(giocatore));
      if (await _specializzazioneEsiste('giocatore', giocatore.id)) {
        await _aggiornaColonnePlayerCard(giocatore);
      } else {
        await _client.from('giocatore').insert({
          'account_id': giocatore.id,
          'ruolo_preferito_in_campo': giocatore.ruoloPreferitoInCampo,
          'piede_dominante': giocatore.piedeDominante,
        });
      }
      await _aggiornaAccount(giocatore.id, {
        'stato_onboarding': giocatore.statoOnboarding,
      });
      return _requireSpecialized<Giocatore>(giocatore.id);
    });
  }

  /// Completa l'onboarding del GestoreCampo con gli stessi tre passi.
  ///
  /// La riga di `gestore_campo` nasce senza `id_account_pagamenti`: lo scrive
  /// l'Edge Function dei pagamenti con la service role (D3), e la policy
  /// INSERT rifiuta un valore non nullo. Se la riga esiste gia' (UC_ACC_1 E3)
  /// l'INSERT si salta: il client non ha colonne aggiornabili su questa
  /// tabella.
  @override
  Future<GestoreCampo> completaOnboardingGestore(GestoreCampo gestore) {
    return _execute(() async {
      await _aggiornaAccount(gestore.id, _colonneProfiloAccount(gestore));
      if (!await _specializzazioneEsiste('gestore_campo', gestore.id)) {
        await _client.from('gestore_campo').insert({'account_id': gestore.id});
      }
      await _aggiornaAccount(gestore.id, {
        'stato_onboarding': gestore.statoOnboarding,
      });
      return _requireSpecialized<GestoreCampo>(gestore.id);
    });
  }

  @override
  Future<Giocatore> aggiornaPlayerCard(Giocatore giocatore) {
    return _execute(() async {
      await _aggiornaColonnePlayerCard(giocatore);
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
