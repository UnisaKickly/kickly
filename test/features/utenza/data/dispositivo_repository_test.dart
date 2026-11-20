import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/utenza/data/in_memory_dispositivo_repository.dart';
import 'package:kickly/features/utenza/data/supabase_dispositivo_repository.dart';
import 'package:kickly/features/utenza/domain/dispositivo_registrato.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> respondEmpty(HttpRequest request, int statusCode) async {
    request.response.statusCode = statusCode;
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

Future<T> _withDispositivoSupabase<T>(
  Future<T> Function(SupabaseDispositivoRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseDispositivoRepository(client));
    });
  } finally {
    await server.close();
  }
}

void main() {
  DispositivoRegistrato dispositivo({
    String id = '',
    String accountId = 'account-1',
    String identificativo = 'device-1',
  }) {
    return DispositivoRegistrato(
      id: id,
      accountId: accountId,
      identificativo: identificativo,
      primoAccesso: DateTime.parse('2026-11-01T09:30:00+00:00'),
      ultimoAccesso: DateTime.parse('2026-11-20T18:15:45.123456+00:00'),
    );
  }

  test('registra il dispositivo con un UUID deterministico', () async {
    final repository = InMemoryDispositivoRepository();

    final saved = await repository.registerDispositivo(
      'account-1',
      dispositivo(),
    );

    expect(saved.id, '00000000-0000-4000-8000-000000000001');
    expect(saved.accountId, 'account-1');
    expect(saved.primoAccesso, DateTime.utc(2026, 11, 1, 9, 30));
    expect(
      saved.ultimoAccesso,
      DateTime.utc(2026, 11, 20, 18, 15, 45, 123, 456),
    );
  });

  test('cerca per account e identificativo e lista i dispositivi', () async {
    final repository = InMemoryDispositivoRepository();
    final first = await repository.registerDispositivo(
      'account-1',
      dispositivo(),
    );
    final second = await repository.registerDispositivo(
      'account-1',
      dispositivo(identificativo: 'device-2'),
    );
    await repository.registerDispositivo(
      'account-2',
      dispositivo(accountId: 'account-2'),
    );

    expect(
      await repository.findByAccountAndIdentificativo('account-1', 'device-1'),
      same(first),
    );
    expect(
      await repository.findByAccountAndIdentificativo('account-1', 'missing'),
      isNull,
    );
    expect(await repository.findByAccount('account-1'), [first, second]);
  });

  test(
    'rifiuta il duplicato account-identificativo con AppException',
    () async {
      final repository = InMemoryDispositivoRepository();
      await repository.registerDispositivo('account-1', dispositivo());

      expect(
        () => repository.registerDispositivo('account-1', dispositivo()),
        throwsA(
          isA<AppException>()
              .having((error) => error.code, 'code', '23505')
              .having(
                (error) => error.message,
                'message',
                'Esiste già un elemento con questi dati.',
              ),
        ),
      );
    },
  );

  test(
    'mantiene l ID fornito e sovrascrive accountId con il parametro',
    () async {
      final repository = InMemoryDispositivoRepository();

      final saved = await repository.registerDispositivo(
        'account-2',
        dispositivo(id: 'device-id', accountId: 'account-1'),
      );

      expect(saved.id, 'device-id');
      expect(saved.accountId, 'account-2');
    },
  );

  test('aggiorna ultimo accesso mantenendo gli altri attributi', () async {
    final repository = InMemoryDispositivoRepository();
    final saved = await repository.registerDispositivo(
      'account-1',
      dispositivo(),
    );
    final ultimoAccesso = DateTime.parse('2026-11-20T20:00:00.000001+00:00');

    await repository.updateUltimoAccesso(saved.id, ultimoAccesso);
    final updated = await repository.findByAccountAndIdentificativo(
      'account-1',
      'device-1',
    );

    expect(updated!.id, saved.id);
    expect(updated.primoAccesso, saved.primoAccesso);
    expect(updated.ultimoAccesso, ultimoAccesso);
  });

  test('aggiorna un dispositivo inesistente senza creare righe', () async {
    final repository = InMemoryDispositivoRepository();

    await repository.updateUltimoAccesso('missing', DateTime.utc(2026, 11, 20));

    expect(await repository.findByAccount('account-1'), isEmpty);
  });

  test('Supabase registra un dispositivo e lo restituisce', () async {
    final row = dispositivo(id: 'device-id').toJson();
    final result = await _withDispositivoSupabase(
      (repository) => repository.registerDispositivo(
        'account-1',
        dispositivo(id: 'client-id'),
      ),
      (request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/rest/v1/dispositivo_registrato');
        await _RestServer().respond(request, 201, row);
      },
    );

    expect(result.id, 'device-id');
    expect(result.accountId, 'account-1');
    expect(
      result.ultimoAccesso,
      DateTime.utc(2026, 11, 20, 18, 15, 45, 123, 456),
    );
  });

  test('Supabase findByAccount mappa le righe e le date', () async {
    final rows = [
      dispositivo(id: 'device-1').toJson(),
      dispositivo(id: 'device-2', identificativo: 'device-2').toJson(),
    ];
    final result = await _withDispositivoSupabase(
      (repository) => repository.findByAccount('account-1'),
      (request) async {
        expect(request.method, 'GET');
        expect(request.uri.path, '/rest/v1/dispositivo_registrato');
        await _RestServer().respond(request, 200, rows);
      },
    );

    expect(result.map((device) => device.id), ['device-1', 'device-2']);
    expect(result.first.primoAccesso, DateTime.utc(2026, 11, 1, 9, 30));
  });

  test('Supabase traduce 23505 in AppException.database', () async {
    final result = await _withDispositivoSupabase<Object?>(
      (repository) => repository
          .registerDispositivo('account-1', dispositivo())
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23505',
        'message': 'duplicate device',
        'details': 'device',
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23505');
  });

  test('Supabase traduce 23503 in AppException.database', () async {
    final result = await _withDispositivoSupabase<Object?>(
      (repository) => repository
          .registerDispositivo('account-1', dispositivo())
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23503',
        'message': 'missing account',
        'details': 'account',
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23503');
  });
}
