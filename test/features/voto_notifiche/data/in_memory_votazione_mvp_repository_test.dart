import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/voto_notifiche/data/in_memory_votazione_mvp_repository.dart';
import 'package:kickly/features/voto_notifiche/domain/votazione_mvp.dart';

VotazioneMVP votazione({
  String id = 'votazione-1',
  String partitaId = 'partita-1',
  String stato = StatoVotazione.aperta,
}) {
  return VotazioneMVP(
    id: id,
    partitaId: partitaId,
    statoVotazione: stato,
    scadenza: DateTime.utc(2026, 11, 22, 20),
  );
}

void main() {
  test('updateStato rifiuta uno stato votazione non ammesso', () async {
    final repository = InMemoryVotazioneMVPRepository(votazioni: [votazione()]);

    await expectLater(
      repository.updateStato('votazione-1', 'sospesa'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23514'),
      ),
    );
  });

  test('updateStato accetta i valori ammessi', () async {
    final repository = InMemoryVotazioneMVPRepository(votazioni: [votazione()]);

    await repository.updateStato('votazione-1', StatoVotazione.chiusa);

    final updated = await repository.findById('votazione-1');
    expect(updated?.statoVotazione, StatoVotazione.chiusa);
  });

  test('il costruttore rifiuta uno stato votazione non ammesso', () {
    expect(
      () => InMemoryVotazioneMVPRepository(
        votazioni: [votazione(stato: 'sospesa')],
      ),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23514'),
      ),
    );
  });
}
