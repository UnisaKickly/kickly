import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/voto_notifiche/data/supabase_votazione_mvp_repository.dart';
import 'package:kickly/features/voto_notifiche/domain/votazione_mvp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server HTTP locale che simula PostgREST per i test a scatola nera.
class _RestServer {
  late final HttpServer _server;

  /// Espone l'indirizzo locale usato dal client finto.
  String get url => 'http://${_server.address.host}:${_server.port}';

  /// Avvia il server con il gestore delle richieste del test.
  Future<void> start(Future<void> Function(HttpRequest request) handler) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(handler);
  }

  /// Restituisce una risposta JSON con lo stato richiesto.
  Future<void> respond(HttpRequest request, int statusCode, Object body) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  /// Arresta il server e libera la porta usata dal test.
  Future<void> close() => _server.close(force: true);
}

/// Crea un repository con un client Supabase diretto al server finto.
Future<T> _withRepository<T>(
  Future<T> Function(SupabaseVotazioneMVPRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseVotazioneMVPRepository(client));
    });
  } finally {
    await server.close();
  }
}

Map<String, dynamic> _votazioneJson({
  String id = 'votazione-1',
  String partitaId = 'partita-1',
  String stato = StatoVotazione.aperta,
  String? vincitoreId,
}) => {
  'id': id,
  'partita_id': partitaId,
  'stato_votazione': stato,
  'scadenza': '2026-11-22T20:00:00.000Z',
  'vincitore_id': vincitoreId,
};

void main() {
  group('Lettura votazioni MVP', () {
    test('tf_mvp_findById restituisce la votazione trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findById('votazione-1'),
        (request) => _RestServer().respond(request, 200, [_votazioneJson()]),
      );

      expect(result, isA<VotazioneMVP>());
      expect(result?.id, 'votazione-1');
    });

    test('tf_mvp_findById restituisce null quando manca', () async {
      final result = await _withRepository(
        (repository) => repository.findById('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });

    test('tf_mvp_findByPartita restituisce la votazione trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findByPartita('partita-1'),
        (request) => _RestServer().respond(request, 200, [_votazioneJson()]),
      );

      expect(result?.partitaId, 'partita-1');
    });

    test('tf_mvp_findByPartita restituisce null quando manca', () async {
      final result = await _withRepository(
        (repository) => repository.findByPartita('partita-assenza'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });
  });

  group('Preferenze MVP', () {
    test('tf_mvp_findPreferenzaVotato restituisce il voto presente', () async {
      final result = await _withRepository(
        (repository) =>
            repository.findPreferenzaVotato('votazione-1', 'votante-1'),
        (request) => _RestServer().respond(request, 200, [
          {'votato_id': 'giocatore-2'},
        ]),
      );

      expect(result, 'giocatore-2');
    });

    test('tf_mvp_findPreferenzaVotato restituisce null se assente', () async {
      final result = await _withRepository(
        (repository) =>
            repository.findPreferenzaVotato('votazione-1', 'votante-1'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });

    test('tf_mvp_registraPreferenza completa il voto nominale', () async {
      var method = '';
      var path = '';
      await _withRepository(
        (repository) => repository.registraPreferenza(
          'votazione-1',
          'votante-1',
          'giocatore-2',
        ),
        (request) async {
          method = request.method;
          path = request.uri.path;
          await _RestServer().respond(request, 201, []);
        },
      );

      expect(method, 'POST');
      expect(path, contains('/preferenza_voto_mvp'));
    });
  });

  group('Aggiornamenti votazione MVP', () {
    test('tf_mvp_updateVincitore aggiorna il vincitore', () async {
      await expectLater(
        _withRepository(
          (repository) =>
              repository.updateVincitore('votazione-1', 'giocatore-2'),
          (request) => _RestServer().respond(request, 200, []),
        ),
        completes,
      );
    });

    test('tf_mvp_updateStato aggiorna lo stato della votazione', () async {
      await expectLater(
        _withRepository(
          (repository) =>
              repository.updateStato('votazione-1', StatoVotazione.chiusa),
          (request) => _RestServer().respond(request, 200, []),
        ),
        completes,
      );
    });
  });

  group('Traduzione errori votazione MVP', () {
    for (final code in ['23505', '23514', '23503']) {
      test('tf_mvp_postgrest_$code diventa AppException', () async {
        final result = await _withRepository<Object?>(
          (repository) => repository
              .registraPreferenza('votazione-1', 'votante-1', 'giocatore-2')
              .then<Object?>((_) => null, onError: (Object error) => error),
          (request) => _RestServer().respond(request, 409, {
            'code': code,
            'message': 'vincolo votazione',
            'details': null,
            'hint': null,
          }),
        );

        expect(result, isA<AppException>());
        expect((result as AppException).code, code);
      });
    }

    test('tf_mvp_42501_permessoRLS_diventa_AppException', () async {
      final result = await _withRepository<Object?>(
        (repository) => repository
            .registraPreferenza('votazione-1', 'votante-1', 'giocatore-2')
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

  test('dg9_domain_non_importa_SDK_esterni', () {
    // Verifica DG9 sull'interfaccia: il Domain deve restare indipendente dagli
    // SDK e dalla tecnologia usata per rendere persistente la votazione.
    final source = File(
      'lib/features/voto_notifiche/domain/votazione_mvp_repository.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('supabase_flutter')));
    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('flutter_stripe')));
  });
}
