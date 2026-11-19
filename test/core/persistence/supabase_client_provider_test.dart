// Test del provider condiviso e della traduzione degli errori Supabase.
//
// Verifica override Riverpod, ciclo di inizializzazione, idempotenza
// e categorizzazione sicura delle eccezioni verso AppException.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/core/persistence/supabase_client_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('supabaseClientProvider', () {
    test('puo essere sovrascritto con MockSupabaseClient', () {
      // Preparazione: viene creato un mock e assegnato al ProviderContainer.
      // Esito atteso: la lettura restituisce proprio il mock fornito.
      final mockClient = MockSupabaseClient();
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(mockClient)],
      );
      addTearDown(container.dispose);

      expect(container.read(supabaseClientProvider), same(mockClient));
    });

    test('letture multiple restituiscono la stessa istanza condivisa', () {
      // Preparazione: un container mantiene un override unico del client.
      // Esito atteso: letture consecutive restituiscono la medesima istanza.
      final mockClient = MockSupabaseClient();
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(mockClient)],
      );
      addTearDown(container.dispose);

      final first = container.read(supabaseClientProvider);
      final second = container.read(supabaseClientProvider);

      expect(first, same(mockClient));
      expect(second, same(mockClient));
      expect(second, same(first));
    });

    test('senza override e senza inizializzazione traduce in configuration', () {
      // Preparazione: Supabase non viene inizializzato e il provider viene letto.
      // Esito atteso: viene esposta una AppException con codice configuration.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      Object? thrown;
      try {
        container.read(supabaseClientProvider);
      } catch (error) {
        thrown = error;
      }

      // Riverpod incapsula l'errore del provider in ProviderException.
      expect(thrown, isNotNull);
      final dynamic providerException = thrown;
      final exception = providerException.exception as AppException;
      expect(exception.code, 'configuration');
      expect(exception.message, 'Configurazione del servizio non disponibile.');
    });
  });

  group('traduzione degli errori', () {
    test('restituisce la stessa AppException senza ri-wrapparla', () {
      // Preparazione: viene creata una AppException gia' tradotta.
      // Esito atteso: translateSupabaseError restituisce la stessa istanza.
      final stackTrace = StackTrace.current;
      final originalError = StateError('causa originale');
      final exception = AppException.permission(
        originalError: originalError,
        stackTrace: stackTrace,
      );

      final translated = translateSupabaseError(
        exception,
        stackTrace: StackTrace.current,
      );

      expect(translated, same(exception));
    });

    test('SocketException viene tradotto in errore network', () {
      // Preparazione: viene fornita una SocketException con testo tecnico.
      // Esito atteso: network conserva la causa e non espone il testo tecnico.
      final stackTrace = StackTrace.current;
      final originalError = SocketException('dettaglio DNS interno');

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, 'network');
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(
        translated.message,
        'Problema di connessione. Controlla la rete e riprova.',
      );
      expect(translated.message, isNot(contains('dettaglio DNS interno')));
    });

    test('TimeoutException viene tradotto in errore network', () {
      // Preparazione: viene fornito un timeout con dettaglio tecnico.
      // Esito atteso: network conserva il dettaglio diagnostico ma mostra testo sicuro.
      final stackTrace = StackTrace.current;
      final originalError = TimeoutException('timeout tecnico interno');

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, 'network');
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(
        translated.message,
        'Problema di connessione. Controlla la rete e riprova.',
      );
      expect(translated.message, isNot(contains('timeout tecnico interno')));
    });

    test(
      'AuthException con status 401, 403 e altri valori diventa permission',
      () {
        // Preparazione: vengono create risposte Auth con codici differenti.
        // Esito atteso: tutti gli errori Auth sono presentati come permessi negati.
        final statusCodes = <String?>['401', '403', '400', null];

        for (final statusCode in statusCodes) {
          final stackTrace = StackTrace.current;
          final originalError = AuthException(
            'messaggio Auth tecnico ${statusCode ?? 'senza codice'}',
            statusCode: statusCode,
          );

          final translated = translateSupabaseError(
            originalError,
            stackTrace: stackTrace,
          );

          expect(translated.code, 'permission');
          expect(translated.originalError, same(originalError));
          expect(translated.stackTrace, same(stackTrace));
          expect(
            translated.message,
            'Non hai i permessi necessari per questa operazione.',
          );
          expect(translated.message, isNot(contains('messaggio Auth tecnico')));
        }
      },
    );

    test('PostgrestException con codici RLS diventa permission', () {
      // Preparazione: vengono usati i codici 42501, PGRST301 e PGRST302.
      // Esito atteso: tutti producono un AppException con codice permission.
      for (final code in ['42501', 'PGRST301', 'PGRST302']) {
        final stackTrace = StackTrace.current;
        final originalError = PostgrestException(
          message: 'messaggio RLS tecnico $code',
          code: code,
          details: 'dettaglio tecnico',
        );

        final translated = translateSupabaseError(
          originalError,
          stackTrace: stackTrace,
        );

        expect(translated.code, 'permission');
        expect(translated.originalError, same(originalError));
        expect(translated.stackTrace, same(stackTrace));
        expect(
          translated.message,
          'Non hai i permessi necessari per questa operazione.',
        );
        expect(translated.message, isNot(contains('messaggio RLS tecnico')));
      }
    });

    test('vincoli database specifici traducono con messaggi leggibili', () {
      // Preparazione: vengono creati duplicati, riferimenti e campi obbligatori.
      // Esito atteso: ogni codice conserva il codice tecnico ma espone un testo sicuro.
      final cases = <String, String>{
        '23505': 'Esiste già un elemento con questi dati.',
        '23503': 'Questo elemento è collegato ad altri dati e non può essere eliminato o modificato.',
        '23502': 'Compila tutti i campi obbligatori.',
      };

      for (final entry in cases.entries) {
        final stackTrace = StackTrace.current;
        final originalError = PostgrestException(
          message: 'errore SQL grezzo ${entry.key}',
          code: entry.key,
          details: 'detail tecnico',
        );

        final translated = translateSupabaseError(
          originalError,
          stackTrace: stackTrace,
        );

        expect(translated.code, entry.key);
        expect(translated.message, entry.value);
        expect(translated.originalError, same(originalError));
        expect(translated.stackTrace, same(stackTrace));
        expect(translated.message, isNot(contains('errore SQL grezzo')));
      }
    });

    test('vincolo PostgreSQL generico 23xxx diventa database', () {
      // Preparazione: viene usato il codice 23514 non coperto da vincoli specifici.
      // Esito atteso: il codice resta 23514 con un messaggio generico leggibile.
      final stackTrace = StackTrace.current;
      final originalError = PostgrestException(
        message: 'check constraint failed: dati privati',
        code: '23514',
        details: 'dettaglio database interno',
      );

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, '23514');
      expect(
        translated.message,
        'Un vincolo del database non è stato rispettato.',
      );
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(translated.message, isNot(contains('check constraint')));
    });

    test('PostgrestException generico diventa database sicuro', () {
      // Preparazione: viene usato un errore PostgREST senza categoria nota.
      // Esito atteso: AppException.database mantiene il codice e nasconde i dettagli.
      final stackTrace = StackTrace.current;
      final originalError = PostgrestException(
        message: 'raw postgrest details',
        code: 'PGRST999',
        details: 'dettaglio interno',
      );

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, 'PGRST999');
      expect(
        translated.message,
        'Impossibile completare l\'operazione sui dati.',
      );
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(translated.message, isNot(contains('raw postgrest details')));
    });

    test('FormatException viene tradotto in errore unexpected', () {
      // Preparazione: viene fornito un formato inatteso con testo tecnico.
      // Esito atteso: il messaggio e' sicuro e contiene solo il codice unexpected.
      final stackTrace = StackTrace.current;
      final originalError = const FormatException('formato tecnico interno');

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, 'unexpected');
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(
        translated.message,
        'Si è verificato un errore imprevisto. Riprova.',
      );
      expect(translated.message, isNot(contains('formato tecnico interno')));
    });

    test('Exception generica viene tradotta in errore unexpected', () {
      // Preparazione: viene fornita una eccezione generica sconosciuta.
      // Esito atteso: viene preservata la causa e mostrato un messaggio imprevisto.
      final stackTrace = StackTrace.current;
      final originalError = Exception('eccezione interna non divulgabile');

      final translated = translateSupabaseError(
        originalError,
        stackTrace: stackTrace,
      );

      expect(translated.code, 'unexpected');
      expect(translated.originalError, same(originalError));
      expect(translated.stackTrace, same(stackTrace));
      expect(
        translated.message,
        'Si è verificato un errore imprevisto. Riprova.',
      );
      expect(
        translated.message,
        isNot(contains('eccezione interna non divulgabile')),
      );
    });
  });
}
