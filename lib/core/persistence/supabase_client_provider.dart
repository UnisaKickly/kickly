import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_exception.dart';

/// Provider condiviso del client Supabase usato dai Repository.
///
/// Centralizza l'accesso a [Supabase.instance.client]: ogni Repository usa
/// questa stessa istanza Riverpod e non crea direttamente un nuovo client.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) {
      try {
        // Recupera il client solo dopo che Supabase è stato inizializzato.
        return Supabase.instance.client;
      } on Object catch (error, stackTrace) {
        // Traduce anche AssertionError e StateError per evitare di esporre
        // errori di inizializzazione tecnici agli strati superiori.
        throw translateSupabaseError(error, stackTrace: stackTrace);
      }
    });

/// Traduce eccezioni tecniche in un errore comprensibile per l'applicazione.
///
/// Mantiene la traduzione idempotente: una [AppException] già prodotta
/// attraversa i Repository senza essere trasformata in un altro errore.
AppException translateSupabaseError(Object error, {StackTrace? stackTrace}) {
  // Rilancia senza ri-wrappare gli errori applicativi già tradotti.
  if (error is AppException) {
    return error;
  }

  // Errori di rete o timeout hanno una sola causa utente: connettività.
  if (error is SocketException || error is TimeoutException) {
    return AppException.network(originalError: error, stackTrace: stackTrace);
  }

  // Supabase deve essere inizializzato prima di accedere al client condiviso.
  if (error is AssertionError || error is StateError) {
    return AppException.configuration(
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  // Auth usa statusCode come String? nella versione installata.
  if (error is AuthException) {
    // Qualunque rifiuto Auth viene presentato come problema di permessi,
    // evitando di mostrare messaggi tecnici come risposta dell'SDK.
    return AppException.permission(
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  // PostgREST espone il codice PostgreSQL/PostgREST tramite la proprietà code.
  if (error is PostgrestException) {
    final String? code = error.code;

    // Questi codici rappresentano accesso negato o policy RLS violata.
    if (code == '42501' || code == 'PGRST301' || code == 'PGRST302') {
      return AppException.permission(
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // 23505 indica un valore duplicato che viola un vincolo univoco.
    if (code == '23505') {
      return AppException.database(
        message: 'Esiste già un elemento con questi dati.',
        code: code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // 23503 indica un riferimento a un dato mancante o collegato.
    if (code == '23503') {
      return AppException.database(
        message:
            'Questo elemento è collegato ad altri dati e non può essere '
            'eliminato o modificato.',
        code: code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // 23502 indica che una colonna obbligatoria non è stata valorizzata.
    if (code == '23502') {
      return AppException.database(
        message: 'Compila tutti i campi obbligatori.',
        code: code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Gli altri codici 23xxx sono vincoli integrità PostgreSQL generici.
    if (code != null && code.startsWith('23')) {
      return AppException.database(
        message: 'Un vincolo del database non è stato rispettato.',
        code: code,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Un errore PostgREST sconosciuto usa un messaggio sicuro e conservato.
    return AppException.database(
      message: 'Impossibile completare l\'operazione sui dati.',
      code: code,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  // Qualunque eccezione non riconosciuta resta un errore imprevisto sicuro.
  return AppException.unexpected(originalError: error, stackTrace: stackTrace);
}
