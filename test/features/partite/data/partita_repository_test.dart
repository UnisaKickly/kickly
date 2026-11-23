import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/partite/data/in_memory_partita_repository.dart';
import 'package:kickly/features/partite/data/supabase_partita_repository.dart';
import 'package:kickly/features/partite/domain/partita.dart';
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
  Future<T> Function(SupabasePartitaRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(
      () => body(
        SupabasePartitaRepository(SupabaseClient(server.url, 'test-anon-key')),
      ),
    );
  } finally {
    await server.close();
  }
}

void main() {
  /// Costruisce una Partita fittizia con stato e dati validi per i test.
  Partita partita({
    String id = '',
    String? legaId,
    String stato = StatoPartita.aperta,
  }) => Partita(
    id: id,
    giocatoreId: 'giocatore-1',
    legaId: legaId,
    dataOra: DateTime.utc(2026, 11, 27, 20),
    tipologia: TipologiaPartita.cinqueVsCinque,
    privacy: legaId == null ? PrivacyPartita.pubblica : PrivacyPartita.privata,
    numPartecipantiRichiesti: 10,
    stato: stato,
    linkCondivisione: null,
  );

  test('tf_par_01_crea_e_trova_la_partita_in_memoria', () async {
    final repository = InMemoryPartitaRepository();
    final created = await repository.createPartita(partita());

    expect(created.id, isNotEmpty);
    expect(created.stato, StatoPartita.aperta);
    expect(await repository.findById(created.id), same(created));
  });

  test('tf_par_partita_filtra_pubbliche_giocatore_e_lega', () async {
    final repository = InMemoryPartitaRepository();
    final publicMatch = await repository.createPartita(partita());
    final leagueMatch = await repository.createPartita(
      partita(legaId: 'lega-1'),
    );

    expect(await repository.findPubbliche(), [publicMatch]);
    expect(await repository.findByGiocatore('giocatore-1'), [
      publicMatch,
      leagueMatch,
    ]);
    expect(await repository.findByLega('lega-1'), [leagueMatch]);
  });

  test('tf_par_partita_cambia_stato_senza_violare_l_entity', () async {
    final repository = InMemoryPartitaRepository();
    final created = await repository.createPartita(partita());

    await repository.updateStato(created.id, StatoPartita.completa);

    expect(
      (await repository.findById(created.id))!.stato,
      StatoPartita.completa,
    );
  });

  test('tf_par_partita_elimina_e_cerca_null', () async {
    final repository = InMemoryPartitaRepository();
    final created = await repository.createPartita(partita());

    await repository.deletePartita(created.id);

    expect(await repository.findById(created.id), isNull);
  });

  test('Supabase createPartita usa INSERT e mappa la riga', () async {
    var path = '';
    var method = '';
    final result = await _withSupabase(
      (repository) => repository.createPartita(partita()),
      (request) async {
        path = request.uri.path;
        method = request.method;
        await _RestServer().respond(
          request,
          201,
          partita(id: 'partita-rpc-id').toJson(),
        );
      },
    );

    expect(method, 'POST');
    expect(path, '/rest/v1/partita');
    expect(result.id, 'partita-rpc-id');
  });

  test('Supabase findPubbliche esclude una partita con lega', () async {
    final result = await _withSupabase(
      (repository) => repository.findPubbliche(),
      (request) => _RestServer().respond(request, 200, [
        partita(id: 'p1').toJson(),
        partita(id: 'p2', legaId: 'lega-1').toJson(),
      ]),
    );

    expect(result.map((item) => item.id), ['p1']);
  });

  test('Supabase traduce 23514 in AppException.database', () async {
    final result = await _withSupabase<Object?>(
      (repository) => repository
          .updateStato('p1', 'Rinviata')
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23514',
        'message': 'check violation',
        'details': null,
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23514');
  });

  // KCK-226: il GRANT per colonna ammette dal client solo UPDATE di stato.
  test('Supabase updatePartita aggiorna solo la colonna stato', () async {
    var method = '';
    var path = '';
    var query = '';
    Object? body;
    await _withSupabase(
      (repository) => repository.updatePartita(
        partita(id: 'p1', stato: StatoPartita.annullata),
      ),
      (request) async {
        method = request.method;
        path = request.uri.path;
        query = request.uri.query;
        body = jsonDecode(await utf8.decoder.bind(request).join());
        await _RestServer().respond(
          request,
          200,
          partita(id: 'p1', stato: StatoPartita.annullata).toJson(),
        );
      },
    );

    expect(method, 'PATCH');
    expect(path, '/rest/v1/partita');
    expect(query, contains('id=eq.p1'));
    expect(body, {'stato': StatoPartita.annullata});
  });
}
