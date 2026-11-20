import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/utenza/data/in_memory_dispositivo_repository.dart';
import 'package:kickly/features/utenza/domain/dispositivo_registrato.dart';

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
}
