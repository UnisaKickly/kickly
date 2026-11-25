// Test dell'adattatore SessioneAutenticazione (KCK-215): avvisa il router a
// ogni login e logout di AutenticazioneControl.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/provider/autenticazione_provider.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';

void main() {
  test('avvisa i listener a ogni login e logout', () async {
    // Preparazione: Control con un account registrato e l'adattatore in
    // ascolto.
    // Esito atteso: dopo il login autenticato e' true, dopo il logout false,
    // e i listener (il router) vengono avvisati entrambe le volte.
    final InMemoryAccountRepository repository = InMemoryAccountRepository();
    await repository.createAccount(
      const Account(
        id: 'account-1',
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Giulia',
        cognome: 'Verdi',
        email: 'giulia.verdi@example.com',
        eta: 24,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
      ),
    );
    repository.impostaPassword(
      'giulia.verdi@example.com',
      'PasswordFittizia1!',
    );
    final AutenticazioneControl control = AutenticazioneControl(
      accountRepository: repository,
    );
    final SessioneAutenticazione sessione = SessioneAutenticazione(control);
    addTearDown(sessione.dispose);
    int avvisi = 0;
    sessione.addListener(() => avvisi++);

    expect(sessione.autenticato, isFalse);

    await control.login('giulia.verdi@example.com', 'PasswordFittizia1!');
    await Future<void>.delayed(Duration.zero);
    expect(sessione.autenticato, isTrue);
    expect(avvisi, 1);

    await control.logout();
    await Future<void>.delayed(Duration.zero);
    expect(sessione.autenticato, isFalse);
    expect(avvisi, 2);
  });
}
