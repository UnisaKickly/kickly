import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/data/supabase_lega_repository.dart';
import 'package:kickly/features/leghe/domain/lega.dart';
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

  Future<void> close() => _server.close(force: true);
}

Future<T> _withLegaSupabase<T>(
  Future<T> Function(SupabaseLegaRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseLegaRepository(client));
    });
  } finally {
    await server.close();
  }
}

void main() {
  Lega lega({
    String id = '',
    String nome = 'Lega del Giovedi',
    String privacy = PrivacyLega.privata,
    String? codiceInvito = 'INVITO-TEST',
    DateTime? scadenzaCodiceInvito,
  }) {
    return Lega(
      id: id,
      nome: nome,
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: privacy,
      codiceInvito: codiceInvito,
      scadenzaCodiceInvito:
          scadenzaCodiceInvito ?? DateTime.utc(2026, 11, 27, 20),
    );
  }

  test(
    'crea una lega e associa il creatore come membro e amministratore',
    () async {
      final repository = InMemoryLegaRepository();

      final created = await repository.createLega(lega(), 'giocatore-1');

      expect(created.id, '00000000-0000-4000-8000-000000000001');
      expect(await repository.findById(created.id), same(created));
      expect(await repository.findByGiocatore('giocatore-1'), [created]);
    },
  );

  test('persiste passivamente codice invito e scadenza', () async {
    final repository = InMemoryLegaRepository();
    final expiration = DateTime.utc(2026, 12, 1, 20);
    final source = lega(
      codiceInvito: 'CODICE-CONTROL',
      scadenzaCodiceInvito: expiration,
    );

    final created = await repository.createLega(source, 'giocatore-1');
    final found = await repository.findByCodiceInvito('CODICE-CONTROL');

    expect(created.codiceInvito, 'CODICE-CONTROL');
    expect(created.scadenzaCodiceInvito, expiration);
    expect(found, same(created));
  });

  test('normalizza il nome per il controllo di unicità', () async {
    final repository = InMemoryLegaRepository();
    await repository.createLega(lega(nome: '  Champions Giovedi  '), 'g1');

    expect(await repository.existsByNome('champions giovedi'), isTrue);
    expect(
      () => repository.createLega(lega(nome: 'CHAMPIONS GIOVEDI'), 'g2'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23505'),
      ),
    );
  });

  test('aggiorna dettagli e codice senza generarlo', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');
    final updated = lega(
      id: created.id,
      nome: 'Lega aggiornata',
      codiceInvito: 'NUOVO-CODICE',
    );

    final saved = await repository.updateLega(updated);

    expect(saved, same(updated));
    expect(await repository.findById(created.id), same(updated));
  });

  test('trova le leghe pubbliche e quelle del giocatore', () async {
    final repository = InMemoryLegaRepository();
    final publicLeague = await repository.createLega(
      lega(nome: 'Pubblica', privacy: PrivacyLega.pubblica),
      'g1',
    );
    final privateLeague = await repository.createLega(
      lega(nome: 'Privata', codiceInvito: 'PRIVATE'),
      'g2',
    );
    await repository.aggiungiMembro(publicLeague.id, 'g2');

    expect(await repository.findPubbliche(), [publicLeague]);
    expect(await repository.findByGiocatore('g2'), [
      publicLeague,
      privateLeague,
    ]);
  });

  test('aggiunge un membro e lo promuove ad amministratore', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    await repository.aggiungiMembro(created.id, 'g2');
    await repository.promuoviAdAdmin(created.id, 'g2');
    await repository.rimuoviMembro(created.id, 'g1');

    expect(await repository.findByGiocatore('g1'), isEmpty);
    expect(await repository.findByGiocatore('g2'), [created]);
  });

  test('blocca la rimozione dell ultimo amministratore', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    expect(
      () => repository.rimuoviMembro(created.id, 'g1'),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', '23514')
            .having(
              (error) => error.message,
              'message',
              'Nomina un altro amministratore prima di uscire.',
            ),
      ),
    );
  });

  test('non promuove un giocatore che non è membro', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    expect(
      () => repository.promuoviAdAdmin(created.id, 'g2'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23503'),
      ),
    );
  });

  test('isAmministratore distingue amministratori e membri', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'giocatore-1');
    await repository.aggiungiMembro(created.id, 'giocatore-2');

    expect(
      await repository.isAmministratore(created.id, 'giocatore-1'),
      isTrue,
    );
    expect(
      await repository.isAmministratore(created.id, 'giocatore-2'),
      isFalse,
    );
    expect(await repository.isAmministratore('lega-assente', 'x'), isFalse);
  });

  test('Supabase isAmministratore legge amministratore_lega', () async {
    var path = '';
    var query = '';
    final result = await _withLegaSupabase(
      (repository) => repository.isAmministratore('lega-1', 'giocatore-1'),
      (request) async {
        path = request.uri.path;
        query = request.uri.query;
        await _RestServer().respond(request, 200, {
          'giocatore_id': 'giocatore-1',
        });
      },
    );

    expect(path, '/rest/v1/amministratore_lega');
    expect(query, contains('lega_id=eq.lega-1'));
    expect(query, contains('giocatore_id=eq.giocatore-1'));
    expect(result, isTrue);
  });

  test('Supabase createLega invoca la RPC e mappa la risposta', () async {
    final source = lega(id: 'ignored-by-rpc');
    final response = lega(id: 'lega-rpc-id').toJson();
    var method = '';
    var path = '';
    final result = await _withLegaSupabase(
      (repository) => repository.createLega(source, 'giocatore-1'),
      (request) async {
        method = request.method;
        path = request.uri.path;
        await _RestServer().respond(request, 200, response);
      },
    );

    expect(method, 'POST');
    expect(path, '/rest/v1/rpc/crea_lega');
    expect(result.id, 'lega-rpc-id');
    expect(result.codiceInvito, 'INVITO-TEST');
  });

  test('Supabase existsByNome filtra con ilike e normalizza in Dart', () async {
    var query = '';
    final result = await _withLegaSupabase(
      (repository) => repository.existsByNome('  Lega 100%  '),
      (request) async {
        query = request.uri.query;
        await _RestServer().respond(request, 200, [
          {'nome': 'Lega 100%'},
          {'nome': 'Lega 100X'},
        ]);
      },
    );

    expect(query, contains('ilike'));
    expect(result, isTrue);
  });

  test('Supabase traduce 23505 in AppException.database', () async {
    final result = await _withLegaSupabase<Object?>(
      (repository) => repository
          .createLega(lega(), 'giocatore-1')
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23505',
        'message': 'duplicate league name',
        'details': 'lega_nome_unico_idx',
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23505');
  });

  test('Supabase traduce 23514 in AppException.database', () async {
    final result = await _withLegaSupabase<Object?>(
      (repository) => repository
          .rimuoviMembro('lega-1', 'giocatore-1')
          .then((_) => null, onError: (Object error) => error),
      (request) async {
        if (request.uri.path.endsWith('/amministratore_lega')) {
          if (request.uri.query.contains('giocatore_id')) {
            await _RestServer().respond(request, 200, [
              {'giocatore_id': 'giocatore-1'},
            ]);
          } else if (request.method == 'GET') {
            await _RestServer().respond(request, 200, [
              {'giocatore_id': 'giocatore-1'},
              {'giocatore_id': 'giocatore-2'},
            ]);
          } else {
            await _RestServer().respond(request, 409, {
              'code': '23514',
              'message': 'last administrator',
              'details': 'constraint',
              'hint': null,
            });
          }
        } else {
          await _RestServer().respond(request, 200, []);
        }
      },
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23514');
  });
}
