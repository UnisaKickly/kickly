// Test di AutenticazioneControl (RF_ACC_3, KCK-208): un test per ogni test
// frame di login (F3) e logout (F4) di docs/test/cp_UC_ACC_1_UC_LEG_1.md.
// Esiti attesi presi dai frame, da RF_ACC_3 e da D16, non dal codice.
// Repository in memoria, nessun accesso al DB.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/account_repository.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';

/// Repository che simula un errore di rete del servizio di autenticazione.
class _RepositorySenzaRete extends InMemoryAccountRepository {
  @override
  Future<String> accedi(String email, String password) async =>
      throw AppException.network();
}

void main() {
  // Dati fittizi: account registrato con onboarding completato.
  const email = 'giulia.verdi@example.com';
  const password = 'PasswordFittizia1!';
  const account = Account(
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

  late InMemoryAccountRepository repository;
  late AutenticazioneControl control;

  setUp(() async {
    repository = InMemoryAccountRepository();
    await repository.createAccount(account);
    repository.impostaPassword(email, password);
    control = AutenticazioneControl(accountRepository: repository);
  });

  test('tf_acc_10_login_con_credenziali_corrette_mostra_dashboard', () async {
    // Preparazione: account registrato con onboarding completato; email
    // registrata, password corretta, campi inseriti.
    // Esito atteso: l'utente accede al proprio account e il sistema mostra la
    // Dashboard (l'Account restituito ha l'onboarding completato).
    final Account autenticato = await control.login(email, password);

    expect(autenticato.id, account.id);
    expect(autenticato.statoOnboarding, StatoOnboarding.completato);
    expect(control.autenticato, isTrue);
  });

  test('tf_acc_11_login_con_email_non_registrata_rifiutato', () async {
    // Preparazione: nessun account con l'email inserita.
    // Esito atteso: l'utente non viene autenticato e resta su FormLogin, con
    // il messaggio generico "Email o password non corretti" (D16).
    await expectLater(
      control.login('nessuno@example.com', password),
      throwsA(
        isA<CredenzialiNonCorretteException>().having(
          (e) => e.message,
          'message',
          'Email o password non corretti',
        ),
      ),
    );
    expect(control.autenticato, isFalse);
  });

  test('tf_acc_12_login_con_password_errata_rifiutato', () async {
    // Preparazione: account registrato, password sbagliata.
    // Esito atteso: l'utente non viene autenticato e resta su FormLogin, con
    // lo stesso messaggio generico di TF_ACC_11 (D16).
    await expectLater(
      control.login(email, 'PasswordSbagliata9!'),
      throwsA(
        isA<CredenzialiNonCorretteException>().having(
          (e) => e.message,
          'message',
          'Email o password non corretti',
        ),
      ),
    );
    expect(control.autenticato, isFalse);
  });

  test('tf_acc_13_login_con_campo_vuoto_errore_sul_campo', () async {
    // Preparazione: modulo di login incompleto (email vuota, poi password
    // vuota).
    // Esito atteso: l'utente non viene autenticato e resta su FormLogin, con
    // l'errore sul campo vuoto (D16).
    await expectLater(
      control.login('   ', password),
      throwsA(
        isA<CampoObbligatorioException>().having(
          (e) => e.campo,
          'campo',
          CampoObbligatorioException.email,
        ),
      ),
    );
    await expectLater(
      control.login(email, ''),
      throwsA(
        isA<CampoObbligatorioException>().having(
          (e) => e.campo,
          'campo',
          CampoObbligatorioException.password,
        ),
      ),
    );
    expect(control.autenticato, isFalse);
  });

  test('tf_acc_14_logout_chiude_la_sessione', () async {
    // Preparazione: utente autenticato che sceglie il logout da
    // ImpostazioniAccount.
    // Esito atteso: la sessione viene chiusa; per accedere di nuovo servono
    // le credenziali.
    await control.login(email, password);
    expect(control.autenticato, isTrue);

    await control.logout();

    expect(control.autenticato, isFalse);
    expect(repository.idAccountAutenticato(), isNull);
    await expectLater(
      control.login(email, 'PasswordSbagliata9!'),
      throwsA(isA<CredenzialiNonCorretteException>()),
    );
  });

  // Test senza frame, suggerito dai PM (KCK-208, commento 11211): sessione
  // chiusa dal servizio, non dal logout del Control.
  test(
    'risulta non autenticato quando il repository chiude la sessione',
    () async {
      // Preparazione: utente autenticato; la sessione viene chiusa dal
      // repository (es. sessione non piu' valida).
      // Esito atteso: il Control non e' piu' autenticato e lo segnala sullo
      // stream dei cambiamenti di sessione.
      final List<bool> eventi = <bool>[];
      final StreamSubscription<bool> sottoscrizione = control
          .cambiamentiSessione
          .listen(eventi.add);
      addTearDown(sottoscrizione.cancel);

      await control.login(email, password);
      await repository.esci();
      await Future<void>.delayed(Duration.zero);

      expect(control.autenticato, isFalse);
      expect(eventi, <bool>[true, false]);
    },
  );

  test('un errore di rete non diventa "credenziali non corrette"', () async {
    // Preparazione: il servizio di autenticazione non e' raggiungibile.
    // Esito atteso: arriva l'AppException di rete, non l'errore di D16.
    final AutenticazioneControl senzaRete = AutenticazioneControl(
      accountRepository: _RepositorySenzaRete(),
    );

    await expectLater(
      senzaRete.login(email, password),
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'network')
            .having(
              (e) => e is CredenzialiNonCorretteException,
              'credenziali',
              isFalse,
            ),
      ),
    );
  });

  test('il codice delle credenziali rifiutate e\' quello approvato', () {
    expect(
      AccountRepository.codiceCredenzialiNonValide,
      'credenziali_non_valide',
    );
  });
}
