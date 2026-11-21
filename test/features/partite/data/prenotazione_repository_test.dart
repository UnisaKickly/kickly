import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/partite/data/in_memory_prenotazione_repository.dart';
import 'package:kickly/features/partite/data/supabase_prenotazione_repository.dart';
import 'package:kickly/features/partite/domain/prenotazione.dart';
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
  Future<T> Function(SupabasePrenotazioneRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(
      () => body(
        SupabasePrenotazioneRepository(
          SupabaseClient(server.url, 'test-anon-key'),
        ),
      ),
    );
  } finally {
    await server.close();
  }
}

void main() {
  /// Costruisce una Prenotazione fittizia con uno slot e importi validi.
  Prenotazione prenotazione({
    String id = '',
    String partitaId = 'partita-1',
    String campoId = 'campo-1',
    String intervallo = '2026-11-27T18:00/2026-11-27T19:00',
    String stato = StatoBlocco.bloccato,
  }) => Prenotazione(
    id: id,
    partitaId: partitaId,
    campoId: campoId,
    intervallo: intervallo,
    statoBlocco: stato,
    scadenzaBlocco: stato == StatoBlocco.bloccato
        ? DateTime.utc(2026, 11, 26, 20)
        : null,
    costoConcordato: 60,
    quotaIndividuale: 6,
    commissione: 3,
    nettoGestore: 57,
  );

  test('tf_par_prenotazione_univoca_per_partita', () async {
    final repository = InMemoryPrenotazioneRepository();
    final created = await repository.createPrenotazione(prenotazione());

    expect(await repository.findByPartita('partita-1'), same(created));
    expect(
      () => repository.createPrenotazione(
        prenotazione(partitaId: 'partita-1', campoId: 'campo-2'),
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', '23505')),
    );
  });

  test('tf_par_prenotazione_rifiuta_slot_sovrapposti', () async {
    final repository = InMemoryPrenotazioneRepository();
    await repository.createPrenotazione(prenotazione());

    expect(
      () => repository.createPrenotazione(
        prenotazione(
          partitaId: 'partita-2',
          intervallo: '2026-11-27T18:30/2026-11-27T19:30',
        ),
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', '23P01')),
    );
  });

  test('tf_par_prenotazione_accetta_slot_consecutivi', () async {
    final repository = InMemoryPrenotazioneRepository();
    await repository.createPrenotazione(prenotazione());

    final consecutive = await repository.createPrenotazione(
      prenotazione(
        partitaId: 'partita-2',
        intervallo: '2026-11-27T19:00/2026-11-27T20:00',
      ),
    );

    expect(await repository.findByCampo('campo-1'), hasLength(2));
    expect(consecutive.partitaId, 'partita-2');
  });

  test('tf_par_prenotazione_conferma_e_liberazione', () async {
    final repository = InMemoryPrenotazioneRepository();
    final created = await repository.createPrenotazione(prenotazione());

    final confirmed = await repository.updateStatoBlocco(
      created.id,
      StatoBlocco.confermato,
      null,
    );
    final released = await repository.updateStatoBlocco(
      created.id,
      StatoBlocco.liberato,
      null,
    );

    expect(confirmed.statoBlocco, StatoBlocco.confermato);
    expect(released.statoBlocco, StatoBlocco.liberato);
  });

  test('Supabase crea prenotazione e mappa le colonne', () async {
    var path = '';
    final result = await _withSupabase(
      (repository) => repository.createPrenotazione(prenotazione()),
      (request) async {
        path = request.uri.path;
        await _RestServer().respond(
          request,
          201,
          prenotazione(id: 'prenotazione-1').toJson(),
        );
      },
    );

    expect(path, '/rest/v1/prenotazione');
    expect(result.id, 'prenotazione-1');
  });

  test('Supabase traduce 23P01 in AppException.database', () async {
    final result = await _withSupabase<Object?>(
      (repository) => repository
          .createPrenotazione(prenotazione())
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23P01',
        'message': 'overlapping slot',
        'details': null,
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23P01');
  });
}
