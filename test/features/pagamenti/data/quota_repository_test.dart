import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/pagamenti/data/supabase_quota_repository.dart';
import 'package:kickly/features/pagamenti/domain/quota.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server REST locale usato come client finto per il repository delle quote.
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

/// Crea un repository di quota connesso al server fittizio.
Future<T> _withRepository<T>(
  Future<T> Function(SupabaseQuotaRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseQuotaRepository(client));
    });
  } finally {
    await server.close();
  }
}

Map<String, dynamic> _quotaJson({
  String id = 'quota-1',
  String partecipazioneId = 'partecipazione-1',
  Object importo = 6,
  String stato = StatoVersamento.daVersare,
}) => {
  'id': id,
  'partecipazione_id': partecipazioneId,
  'importo': importo,
  'stato_versamento': stato,
  'termine_versamento': '2026-11-22T18:00:00.000Z',
};

void main() {
  group('Lettura quote', () {
    test('tf_pag_findById restituisce la quota trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findById('quota-1'),
        (request) => _RestServer().respond(request, 200, [_quotaJson()]),
      );

      expect(result, isA<Quota>());
      expect(result?.id, 'quota-1');
    });

    test('tf_pag_findById restituisce null quando manca', () async {
      final result = await _withRepository(
        (repository) => repository.findById('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });

    test('tf_pag_findByPartecipazione trovata', () async {
      final result = await _withRepository(
        (repository) => repository.findByPartecipazione('partecipazione-1'),
        (request) => _RestServer().respond(request, 200, [_quotaJson()]),
      );

      expect(result?.partecipazioneId, 'partecipazione-1');
    });

    test('tf_pag_findByPartecipazione restituisce null', () async {
      final result = await _withRepository(
        (repository) => repository.findByPartecipazione('inesistente'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isNull);
    });
  });

  group('Quote da versare per partita', () {
    test('tf_pag_01_findDaVersare restituisce lista popolata', () async {
      var query = '';
      final result = await _withRepository(
        (repository) => repository.findDaVersareByPartita('partita-1'),
        (request) async {
          query = request.uri.query;
          await _RestServer().respond(request, 200, [
            _quotaJson(),
            _quotaJson(id: 'quota-2'),
          ]);
        },
      );

      expect(query, contains('partecipazione'));
      expect(result, hasLength(2));
    });

    test('tf_pag_findDaVersare restituisce lista vuota', () async {
      final result = await _withRepository(
        (repository) => repository.findDaVersareByPartita('partita-1'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isEmpty);
    });

    test('tf_pag_01_countDaVersare conta le quote mancanti', () async {
      final result = await _withRepository(
        (repository) => repository.countDaVersareByPartita('partita-1'),
        (request) => _RestServer().respond(request, 200, [
          _quotaJson(),
          _quotaJson(id: 'quota-2'),
        ]),
      );

      expect(result, 2);
    });

    test('tf_pag_countDaVersare restituisce zero', () async {
      final result = await _withRepository(
        (repository) => repository.countDaVersareByPartita('partita-1'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, 0);
    });
  });

  group('Verifica tutte le quote versate', () {
    test('tf_pag_13_tutteLeQuoteVersate restituisce true', () async {
      final result = await _withRepository(
        (repository) => repository.tutteLeQuoteVersate('partita-1'),
        (request) => _RestServer().respond(request, 200, []),
      );

      expect(result, isTrue);
    });

    test('tf_pag_01_tutteLeQuoteVersate restituisce false', () async {
      final result = await _withRepository(
        (repository) => repository.tutteLeQuoteVersate('partita-1'),
        (request) => _RestServer().respond(request, 200, [
          _quotaJson(stato: StatoVersamento.daVersare),
        ]),
      );

      expect(result, isFalse);
    });
  });

  group('Scritture quota', () {
    test('tf_pag_createQuota usa lo stato da_versare', () async {
      final result = await _withRepository(
        (repository) => repository.createQuota(
          Quota(
            id: '',
            partecipazioneId: 'partecipazione-1',
            importo: 6,
            statoVersamento: StatoVersamento.daVersare,
            termineVersamento: DateTime.utc(2026, 11, 22, 18),
          ),
        ),
        (request) =>
            _RestServer().respond(request, 201, _quotaJson(id: 'quota-creata')),
      );

      expect(result.id, 'quota-creata');
      expect(result.statoVersamento, StatoVersamento.daVersare);
    });

    test('tf_pag_updateStatoVersamento passa a versata', () async {
      await expectLater(
        _withRepository(
          (repository) => repository.updateStatoVersamento(
            'quota-1',
            StatoVersamento.versata,
          ),
          (request) => _RestServer().respond(request, 200, []),
        ),
        completes,
      );
    });

    test('tf_pag_10_updateStatoVersamento passa a rimborsata', () async {
      await expectLater(
        _withRepository(
          (repository) => repository.updateStatoVersamento(
            'quota-1',
            StatoVersamento.rimborsata,
          ),
          (request) => _RestServer().respond(request, 200, []),
        ),
        completes,
      );
    });

    test('tf_pag_deleteDaVersare elimina una quota da versare', () async {
      var method = '';
      await _withRepository(
        (repository) => repository.deleteDaVersare('quota-1'),
        (request) async {
          method = request.method;
          await _RestServer().respond(request, 200, []);
        },
      );

      expect(method, 'DELETE');
    });
  });

  group('Mappatura importi numeric', () {
    test('importo intero viene convertito in double', () async {
      final result = await _withRepository(
        (repository) => repository.findById('quota-1'),
        (request) =>
            _RestServer().respond(request, 200, [_quotaJson(importo: 6)]),
      );

      expect(result?.importo, 6.0);
    });

    test('importo decimale resta double', () async {
      final result = await _withRepository(
        (repository) => repository.findById('quota-1'),
        (request) =>
            _RestServer().respond(request, 200, [_quotaJson(importo: 6.5)]),
      );

      expect(result?.importo, 6.5);
    });
  });

  group('Traduzione errori quota', () {
    for (final code in ['23505', '23503', '23514']) {
      test('tf_pag_postgrest_$code diventa AppException', () async {
        final result = await _withRepository<Object?>(
          (repository) => repository
              .createQuota(
                Quota(
                  id: '',
                  partecipazioneId: 'partecipazione-1',
                  importo: 6,
                  statoVersamento: StatoVersamento.daVersare,
                  termineVersamento: DateTime.utc(2026, 11, 22, 18),
                ),
              )
              .then<Object?>((_) => null, onError: (Object error) => error),
          (request) => _RestServer().respond(request, 409, {
            'code': code,
            'message': 'vincolo quota',
            'details': null,
            'hint': null,
          }),
        );

        expect(result, isA<AppException>());
        expect((result as AppException).code, code);
      });
    }
  });
}
