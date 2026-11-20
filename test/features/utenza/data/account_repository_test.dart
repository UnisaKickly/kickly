import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/gestore_campo.dart';
import 'package:kickly/features/utenza/domain/giocatore.dart';

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
}
