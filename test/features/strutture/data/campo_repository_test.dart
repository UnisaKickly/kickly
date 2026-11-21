import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/strutture/data/in_memory_campo_repository.dart';
import 'package:kickly/features/strutture/data/supabase_campo_repository.dart';
import 'package:kickly/features/strutture/domain/campo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server HTTP locale che simula le risposte REST di Supabase nei test.
class _RestServer {
  late final HttpServer _server;

  /// Espone l'indirizzo locale usato dal client Supabase del test.
  String get url => 'http://${_server.address.host}:${_server.port}';

  /// Avvia il server e registra il gestore delle richieste ricevute.
  Future<void> start(Future<void> Function(HttpRequest request) handler) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(handler);
  }

  /// Risponde a una richiesta con un corpo JSON e lo stato HTTP indicati.
  Future<void> respond(HttpRequest request, int statusCode, Object body) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  /// Arresta il server locale liberando le risorse del test.
  Future<void> close() => _server.close(force: true);
}

/// Esegue un test Supabase con un server locale e un repository configurato.
Future<T> _withSupabase<T>(
  Future<T> Function(SupabaseCampoRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseCampoRepository(client));
    });
  } finally {
    await server.close();
  }
}

void main() {
  /// Costruisce un Campo fittizio con dati validi per i test.
  Campo campo({String id = '', String gestore = 'gestore-1'}) => Campo(
    id: id,
    gestoreCampoId: gestore,
    nome: 'Campo A',
    ubicazione: 'Via dello Sport 1',
    tariffaOraria: 60.5,
    orariDisponibilita: '2026-11-27T18:00/2026-11-27T21:00',
  );

  test('tf_par_campo_crea_e_ricerca_in_memoria', () async {
    final repository = InMemoryCampoRepository();
    final created = await repository.createCampo(campo());

    expect(created.id, isNotEmpty);
    expect(await repository.findById(created.id), same(created));
    expect(await repository.findByGestoreCampo('gestore-1'), [created]);
  });

  test('tf_par_campo_aggiorna_tariffa_e_disponibilita', () async {
    final repository = InMemoryCampoRepository();
    final created = await repository.createCampo(campo());
    final updated = Campo(
      id: created.id,
      gestoreCampoId: created.gestoreCampoId,
      nome: 'Campo B',
      ubicazione: created.ubicazione,
      tariffaOraria: 75,
      orariDisponibilita: '2026-11-28T18:00/2026-11-28T22:00',
    );

    expect(await repository.updateCampo(updated), same(updated));
    expect(await repository.getTariffa(created.id), 75.0);
    expect(
      await repository.getDisponibilita(created.id),
      '2026-11-28T18:00/2026-11-28T22:00',
    );
  });

  test('tf_par_campo_cancellazione_rimuove_il_campo', () async {
    final repository = InMemoryCampoRepository();
    final created = await repository.createCampo(campo());

    await repository.deleteCampo(created.id);

    expect(await repository.findById(created.id), isNull);
  });

  test('Supabase crea un campo senza inviare id e mappa la risposta', () async {
    final source = campo();
    final response = campo(id: 'campo-rpc-id').toJson();
    var path = '';
    var method = '';

    final result = await _withSupabase(
      (repository) => repository.createCampo(source),
      (request) async {
        method = request.method;
        path = request.uri.path;
        await _RestServer().respond(request, 201, response);
      },
    );

    expect(method, 'POST');
    expect(path, '/rest/v1/campo');
    expect(result.id, 'campo-rpc-id');
  });

  test('Supabase ricerca per gestore e restituisce Campi', () async {
    final result = await _withSupabase(
      (repository) => repository.findByGestoreCampo('gestore-1'),
      (request) =>
          _RestServer().respond(request, 200, [campo(id: 'c1').toJson()]),
    );

    expect(result, hasLength(1));
    expect(result.first.id, 'c1');
  });

  test('Supabase traduce 23505 in AppException.database', () async {
    final result = await _withSupabase<Object?>(
      (repository) => repository
          .createCampo(campo())
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23505',
        'message': 'duplicate',
        'details': null,
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23505');
  });

  test('Supabase getTariffa legge numeric come double', () async {
    final result = await _withSupabase(
      (repository) => repository.getTariffa('c1'),
      (request) => _RestServer().respond(request, 200, {'tariffa_oraria': 60}),
    );

    expect(result, 60.0);
  });
}
