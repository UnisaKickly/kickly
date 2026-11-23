// Test di AutenticazioneControl.idAccountAutenticato (KCK-249): l'id serve
// alle Boundary delle leghe per passare il Giocatore a GestioneLegaControl.
// Repository in memoria, dati fittizi.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';

void main() {
  const String email = 'giulia.verdi@example.com';
  const String password = 'PasswordFittizia1!';
  const Account account = Account(
    id: '00000000-0000-4000-8000-000000000101',
    ruoloAccount: RuoloAccount.giocatore,
    nome: 'Giulia',
    cognome: 'Verdi',
    email: email,
    eta: 24,
    statoAccount: StatoAccount.attivo,
    statoOnboarding: StatoOnboarding.completato,
    preferenzeNotifiche: '{}',
  );

  // Preparazione: account registrato, prima e dopo login e logout.
  // Esito atteso: null senza sessione, l'id dell'account con la sessione.
  test('segue login e logout', () async {
    final repository = InMemoryAccountRepository();
    await repository.createAccount(account);
    repository.impostaPassword(email, password);
    final control = AutenticazioneControl(accountRepository: repository);

    expect(control.idAccountAutenticato, isNull);
    await control.login(email, password);
    expect(control.idAccountAutenticato, account.id);
    await control.logout();
    expect(control.idAccountAutenticato, isNull);
  });
}
