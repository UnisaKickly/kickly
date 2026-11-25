// Test dei costruttori pubblici di AppException.
//
// Verifica messaggi, codici e dettagli diagnostici esposti dall'eccezione
// applicativa, oltre alla sicurezza del metodo toString().
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';

void main() {
  group('costruttori di AppException', () {
    test('AppException imposta tutti i campi richiesti', () {
      // Preparazione: viene fornito un messaggio, un codice e dettagli originali.
      // Esito atteso: tutti i valori vengono conservati senza trasformazioni.
      final stackTrace = StackTrace.current;
      final originalError = StateError('dettaglio tecnico');

      final exception = AppException(
        message: 'Messaggio leggibile.',
        code: 'custom',
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(exception.message, 'Messaggio leggibile.');
      expect(exception.code, 'custom');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });

    test('AppException.network imposta codice e messaggio di rete', () {
      // Preparazione: viene creato un errore di rete con dettagli diagnostici.
      // Esito atteso: il codice e' network e il messaggio resta leggibile.
      final stackTrace = StackTrace.current;
      final originalError = StateError('socket interno');

      final exception = AppException.network(
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(
        exception.message,
        'Problema di connessione. Controlla la rete e riprova.',
      );
      expect(exception.code, 'network');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });

    test('AppException.permission imposta codice e messaggio dei permessi', () {
      // Preparazione: viene creato un errore di permesso con causa originale.
      // Esito atteso: il codice e' permission e i dettagli vengono conservati.
      final stackTrace = StackTrace.current;
      final originalError = StateError('auth interno');

      final exception = AppException.permission(
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(
        exception.message,
        'Non hai i permessi necessari per questa operazione.',
      );
      expect(exception.code, 'permission');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });

    test('AppException.database imposta messaggio, codice e dettagli', () {
      // Preparazione: viene fornito un vincolo database personalizzato.
      // Esito atteso: tutti i campi sono disponibili per diagnostica e UI.
      final stackTrace = StackTrace.current;
      final originalError = StateError('errore SQL interno');

      final exception = AppException.database(
        message: 'Dato duplicato.',
        code: '23505',
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(exception.message, 'Dato duplicato.');
      expect(exception.code, '23505');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });

    test('AppException.configuration imposta configurazione e dettagli', () {
      // Preparazione: viene creato un errore di configurazione.
      // Esito atteso: il codice e' configuration e i dettagli restano separati.
      final stackTrace = StackTrace.current;
      final originalError = StateError('Supabase non inizializzato');

      final exception = AppException.configuration(
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(exception.message, 'Configurazione del servizio non disponibile.');
      expect(exception.code, 'configuration');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });

    test('AppException.unexpected imposta errore imprevisto e dettagli', () {
      // Preparazione: viene creato un errore applicativo imprevisto.
      // Esito atteso: il codice e' unexpected e la causa viene preservata.
      final stackTrace = StackTrace.current;
      final originalError = FormatException('formato tecnico');

      final exception = AppException.unexpected(
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(
        exception.message,
        'Si è verificato un errore imprevisto. Riprova.',
      );
      expect(exception.code, 'unexpected');
      expect(exception.originalError, same(originalError));
      expect(exception.stackTrace, same(stackTrace));
    });
  });

  group('rappresentazione leggibile', () {
    test('toString restituisce esclusivamente il messaggio utente', () {
      // Preparazione: vengono inseriti messaggio e dettagli tecnici.
      // Esito atteso: toString espone soltanto il messaggio leggibile.
      final exception = AppException(
        message: 'Operazione non disponibile.',
        code: '23505',
        originalError: StateError('SQLSTATE 23505 messaggio interno'),
        stackTrace: StackTrace.current,
      );

      expect(exception.toString(), 'Operazione non disponibile.');
      expect(exception.toString(), isNot(contains('23505')));
      expect(exception.toString(), isNot(contains('SQLSTATE')));
    });

    test(
      'toString dei costruttori specializzati non espone dettagli tecnici',
      () {
        // Preparazione: viene tradotta una eccezione tecnica in AppException.
        // Esito atteso: la rappresentazione contiene solo il testo sicuro.
        final exception = AppException.network(
          originalError: StateError('Host interno irreperibile'),
        );

        expect(
          exception.toString(),
          'Problema di connessione. Controlla la rete e riprova.',
        );
        expect(exception.toString(), isNot(contains('Host interno')));
      },
    );
  });
}
