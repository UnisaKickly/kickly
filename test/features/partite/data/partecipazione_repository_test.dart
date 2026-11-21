import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/partite/data/in_memory_partecipazione_repository.dart';
import 'package:kickly/features/partite/data/supabase_partecipazione_repository.dart';
import 'package:kickly/features/partite/domain/partecipazione.dart';
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

/// Costruisce una Partecipazione fittizia con dati validi per i test.
Partecipazione partecipazione({
  String id = 'partecipazione-1',
  String giocatoreId = 'giocatore-1',
  String partitaId = 'partita-1',
  String risposta = RispostaStato.confermata,
}) => Partecipazione(
  id: id,
  giocatoreId: giocatoreId,
  partitaId: partitaId,
  rispostaStato: risposta,
  dataRisposta: DateTime.utc(2026, 11, 21, 9, 30),
  golPartita: 0,
  assistPartita: 0,
);

void main() {
  test('tf_par_04_lettura_sola_delle_partecipazioni_in_memoria', () async {
    final repository = InMemoryPartecipazioneRepository();
    repository.simulaAggiornamentoRealtime('partita-1', [partecipazione()]);

    expect(await repository.findByPartita('partita-1'), hasLength(1));
    expect(
      await repository.findByGiocatoreEPartita('giocatore-1', 'partita-1'),
      isNotNull,
    );
  });

  test('tf_par_stream_emette_lo_stato_iniziale', () async {
    final repository = InMemoryPartecipazioneRepository();
    repository.simulaAggiornamentoRealtime('partita-1', [partecipazione()]);

    final emitted = await repository.osservaPartecipazioni('partita-1').first;

    expect(emitted, hasLength(1));
    expect(emitted.first.rispostaStato, RispostaStato.confermata);
  });

  test('tf_par_stream_emette_un_aggiornamento_realtime_simulato', () async {
    final repository = InMemoryPartecipazioneRepository();
    final stream = repository.osservaPartecipazioni('partita-1');
    final update = stream.skip(1).first;

    repository.simulaAggiornamentoRealtime('partita-1', [
      partecipazione(),
      partecipazione(id: 'partecipazione-2', giocatoreId: 'giocatore-2'),
    ]);

    final emitted = await update;
    expect(emitted, hasLength(2));
  });

  test('tf_par_stream_rispettare_unicita_giocatore_partita', () async {
    final repository = InMemoryPartecipazioneRepository();
    repository.simulaAggiornamentoRealtime('partita-1', [partecipazione()]);

    final duplicate = await repository.findByGiocatoreEPartita(
      'giocatore-1',
      'partita-1',
    );
    expect(duplicate, isNotNull);
  });

  test(
    'Supabase findByPartita restituisce l elenco iniziale del stream',
    () async {
      final server = _RestServer();
      await server.start((request) async {
        await server.respond(request, 200, [partecipazione().toJson()]);
      });

      try {
        await HttpOverrides.runZoned(() async {
          final repository = SupabasePartecipazioneRepository(
            SupabaseClient(server.url, 'test-anon-key'),
          );
          final emitted = await repository.findByPartita('partita-1');
          expect(emitted, hasLength(1));
        });
      } finally {
        await server.close();
      }
    },
  );

  test('Supabase findByGiocatoreEPartita usa due filtri', () async {
    final server = _RestServer();
    await server.start((request) async {
      expect(request.uri.query, contains('giocatore_id'));
      expect(request.uri.query, contains('partita_id'));
      await server.respond(request, 200, partecipazione().toJson());
    });

    try {
      await HttpOverrides.runZoned(() async {
        final repository = SupabasePartecipazioneRepository(
          SupabaseClient(server.url, 'test-anon-key'),
        );
        final found = await repository.findByGiocatoreEPartita(
          'giocatore-1',
          'partita-1',
        );
        expect(found, isNotNull);
        expect(found!.rispostaStato, RispostaStato.confermata);
      });
    } finally {
      await server.close();
    }
  });
}
