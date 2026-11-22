import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/voto_notifiche/data/supabase_notifica_repository.dart';
import 'package:kickly/features/voto_notifiche/domain/notifica.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server REST locale che restituisce notifiche fittizie al repository.
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

/// Costruisce un repository Notifica con il client HTTP finto.
Future<T> _withRepository<T>(
  Future<T> Function(SupabaseNotificaRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseNotificaRepository(client));
    });
  } finally {
    await server.close();
  }
}

Map<String, dynamic> _notificaJson({
  String id = 'notifica-1',
  String accountId = 'account-1',
  bool statoLettura = false,
}) => {
  'id': id,
  'account_id': accountId,
  'tipo': TipoNotifica.aperturaSondaggioMVP,
  'messaggio': 'La votazione MVP e aperta',
  'stato_lettura': statoLettura,
  'timestamp': '2026-11-21T18:00:00.000Z',
};

void main() {
  group('Consultazione notifiche', () {
    test('tf_not_findById restituisce la notifica trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findById('notifica-1'),
        (request) => _RestServer().respond(request, 200, [_notificaJson()]),
      );

      expect(result, isA<Notifica>());
      expect(result?.id, 'notifica-1');
    });

    test('tf_not_findById restituisce null quando manca', () async {
      final result = await _withRepository(
        (repository) => repository.findById('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });

    test('tf_not_findByAccount restituisce la lista popolata', () async {
      final result = await _withRepository(
        (repository) => repository.findByAccount('account-1'),
        (request) => _RestServer().respond(request, 200, [
          _notificaJson(),
          _notificaJson(id: 'notifica-2'),
        ]),
      );

      expect(result, hasLength(2));
      expect(
        result.every((notifica) => notifica.accountId == 'account-1'),
        isTrue,
      );
    });

    test('tf_not_findByAccount restituisce la lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findByAccount('account-senza-notifiche'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });
  });

  group('Filtro notifiche non lette', () {
    test('tf_not_04_findNonLette filtra lo stato false', () async {
      var query = '';
      final result = await _withRepository(
        (repository) => repository.findNonLetteByAccount('account-1'),
        (request) async {
          query = request.uri.query;
          await _RestServer().respond(request, 200, [
            _notificaJson(statoLettura: false),
          ]);
        },
      );

      expect(query, contains('stato_lettura=eq.false'));
      expect(result, hasLength(1));
      expect(result.first.statoLettura, isFalse);
    });

    test('tf_not_findNonLette restituisce lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findNonLetteByAccount('account-1'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });
  });

  group('Aggiornamento stato lettura', () {
    test('tf_not_04_updateStatoLettura cambia false in true', () async {
      await expectLater(
        _withRepository(
          (repository) => repository.updateStatoLettura('notifica-1', true),
          (request) => _RestServer().respond(request, 200, []),
        ),
        completes,
      );
    });
  });

  group('Traduzione errori notifiche', () {
    test('errore HTTP 401 viene tradotto in AppException', () async {
      final result = await _withRepository<Object?>(
        (repository) => repository
            .findByAccount('account-1')
            .then<Object?>((_) => null, onError: (Object error) => error),
        (request) => _RestServer().respond(request, 401, {
          'code': 'PGRST301',
          'message': 'JWT expired',
          'details': null,
          'hint': null,
        }),
      );

      expect(result, isA<AppException>());
      expect((result as AppException).code, 'permission');
    });

    test('errore RLS 42501 viene tradotto in AppException', () async {
      final result = await _withRepository<Object?>(
        (repository) => repository
            .updateStatoLettura('notifica-1', true)
            .then<Object?>((_) => null, onError: (Object error) => error),
        (request) => _RestServer().respond(request, 409, {
          'code': '42501',
          'message': 'permission denied',
          'details': null,
          'hint': null,
        }),
      );

      expect(result, isA<AppException>());
      expect((result as AppException).code, 'permission');
    });
  });

  test('notifica_repository_nonEspone_metodi_di_creazione', () {
    // La creazione delle notifiche e riservata alle procedure server; il test
    // verifica che il contratto non aggiunga una superficie di scrittura.
    final source = File(
      'lib/features/voto_notifiche/domain/notifica_repository.dart',
    ).readAsStringSync();
    expect(source.toLowerCase(), isNot(contains('create')));
    expect(source.toLowerCase(), isNot(contains('delete')));
  });
}
