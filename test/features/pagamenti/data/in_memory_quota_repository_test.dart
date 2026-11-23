import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/pagamenti/data/in_memory_quota_repository.dart';
import 'package:kickly/features/pagamenti/domain/quota.dart';

Quota quota({
  String id = 'quota-1',
  String partecipazioneId = 'partecipazione-1',
  String stato = StatoVersamento.daVersare,
}) {
  return Quota(
    id: id,
    partecipazioneId: partecipazioneId,
    importo: 6,
    statoVersamento: stato,
    termineVersamento: DateTime.utc(2026, 11, 22, 18),
  );
}

void main() {
  test(
    'createQuota rifiuta una partecipazione gia associata a una quota',
    () async {
      final repository = InMemoryQuotaRepository();
      await repository.createQuota(quota());

      await expectLater(
        repository.createQuota(
          quota(id: 'quota-2', partecipazioneId: 'partecipazione-1'),
        ),
        throwsA(
          isA<AppException>().having((error) => error.code, 'code', '23505'),
        ),
      );
    },
  );

  test('createQuota rifiuta un id quota duplicato', () async {
    final repository = InMemoryQuotaRepository();
    await repository.createQuota(quota());

    await expectLater(
      repository.createQuota(
        quota(id: 'quota-1', partecipazioneId: 'partecipazione-2'),
      ),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23505'),
      ),
    );
  });

  test('createQuota rifiuta uno stato versamento non ammesso', () async {
    final repository = InMemoryQuotaRepository();

    await expectLater(
      repository.createQuota(quota(stato: 'annullata')),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23514'),
      ),
    );
  });

  test('updateStatoVersamento rifiuta uno stato non ammesso', () async {
    final repository = InMemoryQuotaRepository();
    await repository.createQuota(quota());

    await expectLater(
      repository.updateStatoVersamento('quota-1', 'annullata'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23514'),
      ),
    );
  });

  test('updateStatoVersamento accetta i valori ammessi', () async {
    final repository = InMemoryQuotaRepository();
    await repository.createQuota(quota());

    await repository.updateStatoVersamento('quota-1', StatoVersamento.versata);

    final updated = await repository.findById('quota-1');
    expect(updated?.statoVersamento, StatoVersamento.versata);
  });
}
