import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/utenza/data/supabase_account_repository.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/gestore_campo.dart';
import 'package:kickly/features/utenza/domain/giocatore.dart';
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

Future<T> _withAccountSupabase<T>(
  Future<T> Function(SupabaseAccountRepository repository) body,
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = _RestServer();
  await server.start(handler);
  try {
    return await HttpOverrides.runZoned(() async {
      final client = SupabaseClient(server.url, 'test-anon-key');
      return body(SupabaseAccountRepository(client));
    });
  } finally {
    await server.close();
  }
}

void main() {
  const account = Account(
    id: 'account-1',
    ruoloAccount: null,
    nome: 'Mario',
    cognome: 'Rossi',
    email: 'mario@example.com',
    eta: 25,
    statoAccount: StatoAccount.attivo,
    statoOnboarding: StatoOnboarding.inCorso,
    preferenzeNotifiche: '{}',
  );

  test('salva e recupera un Account base per id e email', () async {
    final repository = InMemoryAccountRepository();

    final saved = await repository.createAccount(account);

    expect(saved, same(account));
    expect(await repository.findById('account-1'), same(account));
    expect(await repository.findByEmail('mario@example.com'), same(account));
  });

  test('assegna un UUID deterministico a un Account senza id', () async {
    final repository = InMemoryAccountRepository();
    const senzaId = Account(
      id: '',
      nome: 'Luigi',
      cognome: 'Verdi',
      email: 'luigi@example.com',
      eta: 30,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.inCorso,
      preferenzeNotifiche: '{}',
    );

    final saved = await repository.createAccount(senzaId);

    expect(saved.id, '00000000-0000-4000-8000-000000000001');
  });

  test('completa onboarding e aggiorna la Player Card del Giocatore', () async {
    final repository = InMemoryAccountRepository();
    const giocatore = Giocatore(
      id: 'account-1',
      ruoloAccount: RuoloAccount.giocatore,
      nome: 'Mario',
      cognome: 'Rossi',
      email: 'mario@example.com',
      eta: 25,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.completato,
      preferenzeNotifiche: '{}',
      ruoloPreferitoInCampo: 'Difensore',
      piedeDominante: 'Destro',
    );

    expect(
      await repository.completaOnboardingGiocatore(giocatore),
      same(giocatore),
    );
    expect(await repository.aggiornaPlayerCard(giocatore), same(giocatore));
    expect(await repository.findById('account-1'), same(giocatore));
  });

  test('completa onboarding del GestoreCampo', () async {
    final repository = InMemoryAccountRepository();
    const gestore = GestoreCampo(
      id: 'gestore-1',
      ruoloAccount: RuoloAccount.gestoreCampo,
      nome: 'Anna',
      cognome: 'Bianchi',
      email: 'anna@example.com',
      eta: 35,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.completato,
      preferenzeNotifiche: '{}',
      idAccountPagamenti: 'acct_test_123',
    );

    final saved = await repository.completaOnboardingGestore(gestore);

    expect(saved, same(gestore));
    expect(await repository.findById('gestore-1'), same(gestore));
  });

  test('aggiorna preferenze e stato mantenendo la specializzazione', () async {
    final repository = InMemoryAccountRepository();
    const giocatore = Giocatore(
      id: 'account-1',
      ruoloAccount: RuoloAccount.giocatore,
      nome: 'Mario',
      cognome: 'Rossi',
      email: 'mario@example.com',
      eta: 25,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.completato,
      preferenzeNotifiche: '{}',
      ruoloPreferitoInCampo: 'Difensore',
      piedeDominante: 'Destro',
    );
    await repository.completaOnboardingGiocatore(giocatore);

    await repository.aggiornaPreferenzeNotifiche(
      'account-1',
      '{"partite":false}',
    );
    await repository.aggiornaStatoAccount(
      'account-1',
      StatoAccount.inCancellazione,
    );
    final updated = await repository.findById('account-1');

    expect(updated, isA<Giocatore>());
    expect(updated!.preferenzeNotifiche, '{"partite":false}');
    expect(updated.statoAccount, StatoAccount.inCancellazione);
    expect((updated as Giocatore).ruoloPreferitoInCampo, 'Difensore');
  });

  test(
    'deleteAccount elimina l account e una ricerca assente restituisce null',
    () async {
      final repository = InMemoryAccountRepository();
      await repository.createAccount(account);

      await repository.deleteAccount('account-1');

      expect(await repository.findById('account-1'), isNull);
      expect(await repository.findByEmail('mario@example.com'), isNull);
    },
  );

  test('Supabase findById mappa Account e Giocatore', () async {
    final result = await _withAccountSupabase(
      (repository) => repository.findById('account-1'),
      (request) async {
        await _RestServer().respond(request, 200, [
          {
            ...account.toJson(),
            'giocatore': {
              'account_id': 'account-1',
              'ruolo_preferito_in_campo': 'Difensore',
              'piede_dominante': 'Destro',
            },
            'gestore_campo': null,
          },
        ]);
      },
    );

    expect(result, isA<Giocatore>());
    expect(result!.id, 'account-1');
    expect((result as Giocatore).ruoloPreferitoInCampo, 'Difensore');
  });

  test('Supabase createAccount usa upsert e mappa la risposta', () async {
    var method = '';
    var path = '';
    final result = await _withAccountSupabase(
      (repository) => repository.createAccount(account),
      (request) async {
        method = request.method;
        path = request.uri.path;
        await _RestServer().respond(request, 200, account.toJson());
      },
    );

    expect(method, 'POST');
    expect(path, '/rest/v1/account');
    expect(result.id, 'account-1');
    expect(result.email, 'mario@example.com');
  });

  test(
    'Supabase aggiornaPlayerCard segnala specializzazione mancante',
    () async {
      const giocatore = Giocatore(
        id: 'account-1',
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Mario',
        cognome: 'Rossi',
        email: 'mario@example.com',
        eta: 25,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
        ruoloPreferitoInCampo: 'Difensore',
        piedeDominante: 'Destro',
      );
      Object? error;
      try {
        await _withAccountSupabase(
          (repository) => repository.aggiornaPlayerCard(giocatore),
          (request) async {
            if (request.method == 'PATCH') {
              await _RestServer().respondEmpty(request, 204);
            } else {
              await _RestServer().respond(request, 200, [
                {...account.toJson(), 'giocatore': null, 'gestore_campo': null},
              ]);
            }
          },
        );
      } catch (caught) {
        error = caught;
      }

      expect(error, isA<AppException>());
      expect((error as AppException).code, 'unexpected');
    },
  );

  test('Supabase traduce 23505 in AppException.database', () async {
    final result = await _withAccountSupabase<Object?>(
      (repository) => repository
          .createAccount(account)
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23505',
        'message': 'duplicate email',
        'details': 'email',
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23505');
  });

  test('Supabase traduce 23503 in AppException.database', () async {
    final result = await _withAccountSupabase<Object?>(
      (repository) => repository
          .deleteAccount('account-1')
          .then<Object?>((_) => null, onError: (Object error) => error),
      (request) => _RestServer().respond(request, 409, {
        'code': '23503',
        'message': 'foreign key',
        'details': 'account',
        'hint': null,
      }),
    );

    expect(result, isA<AppException>());
    expect((result as AppException).code, '23503');
  });
}
