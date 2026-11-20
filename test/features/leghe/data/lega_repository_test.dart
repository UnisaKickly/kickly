import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  Lega lega({
    String id = '',
    String nome = 'Lega del Giovedi',
    String privacy = PrivacyLega.privata,
    String? codiceInvito = 'INVITO-TEST',
    DateTime? scadenzaCodiceInvito,
  }) {
    return Lega(
      id: id,
      nome: nome,
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: privacy,
      codiceInvito: codiceInvito,
      scadenzaCodiceInvito:
          scadenzaCodiceInvito ?? DateTime.utc(2026, 11, 27, 20),
    );
  }

  test(
    'crea una lega e associa il creatore come membro e amministratore',
    () async {
      final repository = InMemoryLegaRepository();

      final created = await repository.createLega(lega(), 'giocatore-1');

      expect(created.id, '00000000-0000-4000-8000-000000000001');
      expect(await repository.findById(created.id), same(created));
      expect(await repository.findByGiocatore('giocatore-1'), [created]);
    },
  );

  test('persiste passivamente codice invito e scadenza', () async {
    final repository = InMemoryLegaRepository();
    final expiration = DateTime.utc(2026, 12, 1, 20);
    final source = lega(
      codiceInvito: 'CODICE-CONTROL',
      scadenzaCodiceInvito: expiration,
    );

    final created = await repository.createLega(source, 'giocatore-1');
    final found = await repository.findByCodiceInvito('CODICE-CONTROL');

    expect(created.codiceInvito, 'CODICE-CONTROL');
    expect(created.scadenzaCodiceInvito, expiration);
    expect(found, same(created));
  });

  test('normalizza il nome per il controllo di unicità', () async {
    final repository = InMemoryLegaRepository();
    await repository.createLega(lega(nome: '  Champions Giovedi  '), 'g1');

    expect(await repository.existsByNome('champions giovedi'), isTrue);
    expect(
      () => repository.createLega(lega(nome: 'CHAMPIONS GIOVEDI'), 'g2'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23505'),
      ),
    );
  });

  test('aggiorna dettagli e codice senza generarlo', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');
    final updated = lega(
      id: created.id,
      nome: 'Lega aggiornata',
      codiceInvito: 'NUOVO-CODICE',
    );

    final saved = await repository.updateLega(updated);

    expect(saved, same(updated));
    expect(await repository.findById(created.id), same(updated));
  });

  test('trova le leghe pubbliche e quelle del giocatore', () async {
    final repository = InMemoryLegaRepository();
    final publicLeague = await repository.createLega(
      lega(nome: 'Pubblica', privacy: PrivacyLega.pubblica),
      'g1',
    );
    final privateLeague = await repository.createLega(
      lega(nome: 'Privata', codiceInvito: 'PRIVATE'),
      'g2',
    );
    await repository.aggiungiMembro(publicLeague.id, 'g2');

    expect(await repository.findPubbliche(), [publicLeague]);
    expect(await repository.findByGiocatore('g2'), [
      publicLeague,
      privateLeague,
    ]);
  });

  test('aggiunge un membro e lo promuove ad amministratore', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    await repository.aggiungiMembro(created.id, 'g2');
    await repository.promuoviAdAdmin(created.id, 'g2');
    await repository.rimuoviMembro(created.id, 'g1');

    expect(await repository.findByGiocatore('g1'), isEmpty);
    expect(await repository.findByGiocatore('g2'), [created]);
  });

  test('blocca la rimozione dell ultimo amministratore', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    expect(
      () => repository.rimuoviMembro(created.id, 'g1'),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', '23514')
            .having(
              (error) => error.message,
              'message',
              'Nomina un altro amministratore prima di uscire.',
            ),
      ),
    );
  });

  test('non promuove un giocatore che non è membro', () async {
    final repository = InMemoryLegaRepository();
    final created = await repository.createLega(lega(), 'g1');

    expect(
      () => repository.promuoviAdAdmin(created.id, 'g2'),
      throwsA(
        isA<AppException>().having((error) => error.code, 'code', '23503'),
      ),
    );
  });
}
