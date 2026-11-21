import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/pagamenti/data/supabase_transazione_repository.dart';
import 'package:kickly/features/pagamenti/domain/transazione.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server HTTP locale che simula le sole risposte REST di lettura.
class _RestServer {
  late final HttpServer _server;

  String get url => 'http://${_server.address.host}:${_server.port}';

  Future<void> start(Future<void> Function(HttpRequest request) handler) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(handler);
  }

  Future<void> respond(HttpRequest request, int statusCode, Object body) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// Crea un repository in sola lettura con client REST finto.
Future<T> _withRepository<T>(
  Future<T> Function(SupabaseTransazioneRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseTransazioneRepository(client));
    });
  } finally {
    await server.close();
  }
}

Map<String, dynamic> _transazioneJson({
  String id = 'transazione-1',
  String? quotaId = 'quota-1',
  String? prenotazioneId,
  String? gestoreCampoId,
  String? transazioneOriginariaId,
  Object importo = 6,
  String? dataEsito,
  String riferimentoEsterno = 'evt-test-1',
}) => {
  'id': id,
  'quota_id': quotaId,
  'prenotazione_id': prenotazioneId,
  'gestore_campo_id': gestoreCampoId,
  'transazione_originaria_id': transazioneOriginariaId,
  'tipo': TipoTransazione.pagamento,
  'importo': importo,
  'stato': StatoTransazione.completata,
  'data_esito': dataEsito,
  'riferimento_esterno': riferimentoEsterno,
};

void main() {
  group('Lettura transazioni', () {
    test('tf_pag_findById restituisce la transazione trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findById('transazione-1'),
        (request) => _RestServer().respond(request, 200, [_transazioneJson()]),
      );

      expect(result, isA<Transazione>());
      expect(result?.id, 'transazione-1');
    });

    test('tf_pag_findById restituisce null', () async {
      final result = await _withRepository(
        (repository) => repository.findById('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });

    test('tf_pag_findByQuota restituisce la lista nominale', () async {
      final result = await _withRepository(
        (repository) => repository.findByQuota('quota-1'),
        (request) => _RestServer().respond(request, 200, [_transazioneJson()]),
      );

      expect(result, hasLength(1));
      expect(result.first.quotaId, 'quota-1');
    });

    test('tf_pag_findByQuota restituisce lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findByQuota('quota-senza-transazioni'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });

    test('tf_pag_findByPrenotazione restituisce la lista nominale', () async {
      final result = await _withRepository(
        (repository) => repository.findByPrenotazione('prenotazione-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(prenotazioneId: 'prenotazione-1'),
        ]),
      );

      expect(result, hasLength(1));
      expect(result.first.prenotazioneId, 'prenotazione-1');
    });

    test('tf_pag_findByPrenotazione restituisce lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findByPrenotazione('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });

    test('tf_pag_findByGestoreCampo restituisce la lista nominale', () async {
      final result = await _withRepository(
        (repository) => repository.findByGestoreCampo('gestore-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(gestoreCampoId: 'gestore-1'),
        ]),
      );

      expect(result, hasLength(1));
      expect(result.first.gestoreCampoId, 'gestore-1');
    });

    test('tf_pag_findByGestoreCampo restituisce lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findByGestoreCampo('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });

    test('tf_pag_findByRiferimentoEsterno trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findByRiferimentoEsterno('evt-test-1'),
        (request) => _RestServer().respond(request, 200, [_transazioneJson()]),
      );

      expect(result?.riferimentoEsterno, 'evt-test-1');
    });

    test('tf_pag_findByRiferimentoEsterno restituisce null', () async {
      final result = await _withRepository(
        (repository) => repository.findByRiferimentoEsterno('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });
  });

  group('Mappatura campi nullable e importi', () {
    test('campi nullable vengono mappati a null', () async {
      final result = await _withRepository(
        (repository) => repository.findById('transazione-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(
            quotaId: null,
            prenotazioneId: null,
            gestoreCampoId: null,
            transazioneOriginariaId: null,
            dataEsito: null,
          ),
        ]),
      );

      expect(result?.quotaId, isNull);
      expect(result?.prenotazioneId, isNull);
      expect(result?.gestoreCampoId, isNull);
      expect(result?.transazioneOriginariaId, isNull);
      expect(result?.dataEsito, isNull);
    });

    test('data_esito valorizzata viene mappata a DateTime', () async {
      final result = await _withRepository(
        (repository) => repository.findById('transazione-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(dataEsito: '2026-11-21T19:30:00.000Z'),
        ]),
      );

      expect(result?.dataEsito, isA<DateTime>());
    });

    test('importo intero viene mappato in double', () async {
      final result = await _withRepository(
        (repository) => repository.findById('transazione-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(importo: 10),
        ]),
      );

      expect(result?.importo, 10.0);
    });

    test('importo decimale viene mappato in double', () async {
      final result = await _withRepository(
        (repository) => repository.findById('transazione-1'),
        (request) => _RestServer().respond(request, 200, [
          _transazioneJson(importo: 10.5),
        ]),
      );

      expect(result?.importo, 10.5);
    });
  });

  group('Traduzione errori transazioni', () {
    test('errore RLS PGRST301 diventa AppException', () async {
      final result = await _withRepository<Object?>(
        (repository) => repository
            .findById('transazione-1')
            .then<Object?>((_) => null, onError: (Object error) => error),
        (request) => _RestServer().respond(request, 401, {
          'code': 'PGRST301',
          'message': 'JWT expired',
          'details': null,
          'hint': null,
        }),
      );

      expect(result, isA<AppException>());
    });

    test('errore di rete diventa AppException.network', () async {
      final server = _RestServer();
      await server.start((request) async {
        await server.respond(request, 200, []);
      });
      final url = server.url;
      await server.close();

      final result = await HttpOverrides.runZoned(() async {
        final client = SupabaseClient(url, 'test-anon-key');
        final repository = SupabaseTransazioneRepository(client);
        try {
          await repository.findById('transazione-1');
          return null;
        } catch (error) {
          return error;
        }
      });

      expect(result, isA<AppException>());
      expect((result as AppException).code, 'network');
    });
  });

  test('dg1_dg2_transazione_repository_e_sola_lettura', () {
    // Il test strutturale verifica DG1 e DG2 senza modificare il codice:
    // nessuna API di scrittura o RPC deve comparire nei contratti o nell'SDK.
    final domainSource = File(
      'lib/features/pagamenti/domain/transazione_repository.dart',
    ).readAsStringSync();
    final dataSource = File(
      'lib/features/pagamenti/data/supabase_transazione_repository.dart',
    ).readAsStringSync();

    for (final source in [domainSource, dataSource]) {
      expect(source, isNot(contains('.insert(')));
      expect(source, isNot(contains('.update(')));
      expect(source, isNot(contains('.upsert(')));
      expect(source, isNot(contains('.delete(')));
      expect(source, isNot(contains('.rpc(')));
      expect(source, isNot(RegExp(r'\bcreate[A-Z_]?')));
      expect(source, isNot(RegExp(r'\bupdate[A-Z_]')));
      expect(source, isNot(RegExp(r'\bdelete[A-Z_]')));
    }
  });
}
