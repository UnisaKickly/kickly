import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/voto_notifiche/data/in_memory_notifica_repository.dart';
import 'package:kickly/features/voto_notifiche/domain/notifica.dart';

/// Costruisce una notifica fittizia per i test in memoria.
Notifica notifica({
  String id = 'notifica-1',
  String accountId = 'account-1',
  bool statoLettura = false,
  String messaggio = 'Messaggio di prova',
}) {
  return Notifica(
    id: id,
    accountId: accountId,
    tipo: TipoNotifica.aperturaSondaggioMVP,
    messaggio: messaggio,
    statoLettura: statoLettura,
    timestamp: DateTime.utc(2026, 11, 22, 20),
  );
}

void main() {
  test('findById restituisce la notifica trovata', () async {
    final repository = InMemoryNotificaRepository(notifiche: [notifica()]);

    final found = await repository.findById('notifica-1');

    expect(found?.id, 'notifica-1');
  });

  test('findById restituisce null quando la notifica manca', () async {
    final repository = InMemoryNotificaRepository();

    expect(await repository.findById('inesistente'), isNull);
  });

  test('findByAccount restituisce la lista popolata', () async {
    final repository = InMemoryNotificaRepository(
      notifiche: [
        notifica(),
        notifica(id: 'notifica-2', accountId: 'account-1'),
        notifica(id: 'notifica-3', accountId: 'account-2'),
      ],
    );

    final found = await repository.findByAccount('account-1');

    expect(found, hasLength(2));
  });

  test('findByAccount restituisce una lista vuota', () async {
    final repository = InMemoryNotificaRepository(notifiche: [notifica()]);

    expect(await repository.findByAccount('account-senza-notifiche'), isEmpty);
  });

  test(
    'findNonLetteByAccount restituisce solo le notifiche non lette',
    () async {
      final repository = InMemoryNotificaRepository(
        notifiche: [
          notifica(id: 'notifica-1', statoLettura: false),
          notifica(id: 'notifica-2', statoLettura: true),
        ],
      );

      final found = await repository.findNonLetteByAccount('account-1');

      expect(found, hasLength(1));
      expect(found.first.id, 'notifica-1');
    },
  );

  test('updateStatoLettura cambia false in true', () async {
    final repository = InMemoryNotificaRepository(notifiche: [notifica()]);

    await repository.updateStatoLettura('notifica-1', true);

    final updated = await repository.findById('notifica-1');
    expect(updated?.statoLettura, isTrue);
  });

  test('updateStatoLettura lascia invariati gli altri campi', () async {
    final repository = InMemoryNotificaRepository(
      notifiche: [
        notifica(accountId: 'account-42', messaggio: 'Messaggio persistente'),
      ],
    );

    await repository.updateStatoLettura('notifica-1', true);
    final updated = await repository.findById('notifica-1');

    expect(updated?.id, 'notifica-1');
    expect(updated?.accountId, 'account-42');
    expect(updated?.tipo, TipoNotifica.aperturaSondaggioMVP);
    expect(updated?.messaggio, 'Messaggio persistente');
    expect(updated?.timestamp, DateTime.utc(2026, 11, 22, 20));
  });

  test(
    'l implementazione in memoria espone metodi di sola lettura e update',
    () {
      // Verifica strutturale: la creazione di Notifica resta responsabilita
      // delle procedure lato server e non fa parte del repository in memoria.
      final source = File(
        'lib/features/voto_notifiche/data/in_memory_notifica_repository.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('createNotifica')));
      expect(source, isNot(contains('insert')));
      expect(source, isNot(contains('deleteNotifica')));
    },
  );
}
