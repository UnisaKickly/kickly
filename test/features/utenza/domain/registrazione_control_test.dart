import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/account_repository.dart';
import 'package:kickly/features/utenza/domain/giocatore.dart';
import 'package:kickly/features/utenza/domain/registrazione_control.dart';
import 'package:kickly/features/utenza/domain/validatore_password.dart';

void main() {
  const passwordValida = 'PasswordFittizia1!';

  RegistrazioneControl creaControl(InMemoryAccountRepository repository) {
    return RegistrazioneControl(accountRepository: repository);
  }

  Future<String> registraUtente(
    RegistrazioneControl control, {
    String? email = 'mario@example.com',
    String? password = passwordValida,
    String? nome = 'Mario',
    String? cognome = 'Rossi',
    int? eta = 25,
  }) {
    return control.registra(
      email: email,
      password: password,
      nome: nome,
      cognome: cognome,
      eta: eta,
    );
  }

  test('tf_acc_01_registra_account_e_avvia_onboarding', () async {
    // Preparazione: utente non registrato con i campi presenti e password conforme.
    // Esito atteso (UC_ACC_1 passi 1-5): Account attivo e in corso, senza ruolo;
    // al ripristino il sistema propone la scelta del ruolo.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);

    expect(control.richiediModulo(), [
      'nome',
      'cognome',
      'email',
      'password',
      'eta',
    ]);
    final id = await registraUtente(control);
    final account = await repository.findById(id);

    expect(account, isNotNull);
    expect(account!.statoAccount, StatoAccount.attivo);
    expect(account.statoOnboarding, StatoOnboarding.inCorso);
    expect(account.ruoloAccount, isNull);
    expect(await repository.findByEmail('mario@example.com'), isNotNull);
    expect(
      control.passoOnboardingDaRiprendere(account),
      PassoOnboarding.sceltaRuolo,
    );
  });

  test('tf_acc_02_email_gia_registrata', () async {
    // Preparazione: esiste gia' un account con la stessa email.
    // Esito atteso (UC_ACC_1 E1): AppException email_gia_registrata, l'account
    // esistente resta invariato, non si crea il nuovo account e si riparte dal passo 3.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);
    final idEsistente = await registraUtente(control);

    await expectLater(
      registraUtente(control),
      throwsA(
        isA<AppException>().having(
          (errore) => errore.code,
          'code',
          AccountRepository.codiceEmailGiaRegistrata,
        ),
      ),
    );
    final accountEsistente = await repository.findByEmail('mario@example.com');
    expect(accountEsistente, isNotNull);
    expect(accountEsistente!.id, idEsistente);
    expect(accountEsistente.statoAccount, StatoAccount.attivo);
    expect(accountEsistente.statoOnboarding, StatoOnboarding.inCorso);
  });

  test('tf_acc_03_campo_obbligatorio_mancante', () async {
    // Preparazione: modulo privo di un campo obbligatorio (eta').
    // Esito atteso: errore specifico, Account non creato e compilazione da ripetere al passo 3.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);

    await expectLater(
      registraUtente(control, eta: null),
      throwsA(
        isA<AppException>()
            .having((errore) => errore.code, 'code', 'campo_obbligatorio')
            .having((errore) => errore.message, 'message', "Inserisci l'età"),
      ),
    );
    expect(await repository.findByEmail('mario@example.com'), isNull);
  });

  test('tf_acc_04_password_debole', () async {
    // Preparazione: modulo completo con password debole; si verificano anche
    // i limiti D28 del validatore condiviso per registrazione e recupero.
    // Esito atteso (UC_ACC_1 E2): errore specifico, Account non creato e
    // compilazione da ripetere al passo 3.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);

    expect(() => validaPassword('Abcdefg1'), returnsNormally);
    for (final password in ['Abc1234', '12345678', 'abcdefgh']) {
      expect(
        () => validaPassword(password),
        throwsA(isA<PasswordDeboleException>()),
      );
    }

    for (final eta in [13, 121]) {
      await expectLater(
        registraUtente(control, email: 'eta-$eta@example.com', eta: eta),
        throwsA(
          isA<AppException>()
              .having((errore) => errore.code, 'code', 'eta_non_valida')
              .having(
                (errore) => errore.message,
                'message',
                "L'età deve essere compresa tra 14 e 120 anni",
              ),
        ),
      );
      expect(await repository.findByEmail('eta-$eta@example.com'), isNull);
    }

    await registraUtente(control, email: 'eta-14@example.com', eta: 14);
    await registraUtente(control, email: 'eta-120@example.com', eta: 120);

    await expectLater(
      registraUtente(control, password: 'password'),
      throwsA(
        isA<PasswordDeboleException>().having(
          (errore) => errore.message,
          'message',
          'La password deve avere almeno 8 caratteri, una lettera e un numero',
        ),
      ),
    );
    expect(await repository.findByEmail('mario@example.com'), isNull);
  });

  test('tf_acc_05_sceglie_giocatore_e_salva_player_card', () async {
    // Preparazione: Account appena creato; il Giocatore sceglie il ruolo e
    // conferma ruolo in campo e piede dominante nella Player Card.
    // Esito atteso (UC_ACC_1 passi 6-9, D11): ruolo definitivo, Player Card
    // salvata, onboarding completato e nessun passo di onboarding da riprendere.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);
    final id = await registraUtente(control);

    await control.confermaRuolo(id);
    final giocatoreInConfigurazione = await repository.findById(id);
    expect(giocatoreInConfigurazione, isA<Giocatore>());
    final giocatoreVuoto = giocatoreInConfigurazione! as Giocatore;
    expect(giocatoreVuoto.ruoloAccount, RuoloAccount.giocatore);
    expect(giocatoreVuoto.ruoloPreferitoInCampo, isNull);
    expect(giocatoreVuoto.piedeDominante, isNull);
    expect(giocatoreVuoto.statoOnboarding, StatoOnboarding.inCorso);

    final giocatore = await control.salvaPlayerCard(
      id,
      ruoloPreferitoInCampo: 'Difensore',
      piedeDominante: 'Destro',
    );

    expect(giocatore.ruoloAccount, RuoloAccount.giocatore);
    expect(giocatore.ruoloPreferitoInCampo, 'Difensore');
    expect(giocatore.piedeDominante, 'Destro');
    expect(giocatore.statoOnboarding, StatoOnboarding.completato);

    final giocatoreSalvato = await repository.findById(id);
    expect(giocatoreSalvato, isA<Giocatore>());
    final giocatorePersistito = giocatoreSalvato! as Giocatore;
    expect(giocatorePersistito.ruoloPreferitoInCampo, 'Difensore');
    expect(giocatorePersistito.piedeDominante, 'Destro');
    expect(giocatorePersistito.ruoloAccount, RuoloAccount.giocatore);
    expect(giocatorePersistito.statoOnboarding, StatoOnboarding.completato);
    expect(
      control.passoOnboardingDaRiprendere(giocatorePersistito),
      PassoOnboarding.nessuno,
    );

    final giocatoreCompletoInCorso = Giocatore(
      id: giocatore.id,
      ruoloAccount: RuoloAccount.giocatore,
      nome: giocatore.nome,
      cognome: giocatore.cognome,
      email: giocatore.email,
      eta: giocatore.eta,
      statoAccount: giocatore.statoAccount,
      statoOnboarding: StatoOnboarding.inCorso,
      preferenzeNotifiche: giocatore.preferenzeNotifiche,
      ruoloPreferitoInCampo: giocatore.ruoloPreferitoInCampo,
      piedeDominante: giocatore.piedeDominante,
    );
    expect(
      control.passoOnboardingDaRiprendere(giocatoreCompletoInCorso),
      PassoOnboarding.nessuno,
    );
  });

  test('tf_acc_07_player_card_incompleta', () async {
    // Preparazione: Giocatore nella configurazione, con ruolo in campo ma senza
    // piede dominante.
    // Esito atteso (UC_ACC_1 passo 8, D16): errore sul campo mancante, dati non
    // salvati, onboarding in corso e configurazione Player Card da riprendere.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);
    final id = await registraUtente(control);
    await control.confermaRuolo(id);

    await expectLater(
      control.salvaPlayerCard(
        id,
        ruoloPreferitoInCampo: 'Difensore',
        piedeDominante: null,
      ),
      throwsA(
        isA<AppException>()
            .having((errore) => errore.code, 'code', 'player_card_incompleta')
            .having(
              (errore) => errore.message,
              'message',
              'Seleziona il piede dominante',
            ),
      ),
    );
    final giocatore = await repository.findById(id);
    expect(giocatore, isA<Giocatore>());
    final giocatorePersistito = giocatore! as Giocatore;
    expect(giocatorePersistito.piedeDominante, isNull);
    expect(giocatorePersistito.ruoloPreferitoInCampo, isNull);
    expect(giocatorePersistito.ruoloAccount, RuoloAccount.giocatore);
    expect(giocatorePersistito.statoOnboarding, StatoOnboarding.inCorso);
    expect(
      control.passoOnboardingDaRiprendere(giocatorePersistito),
      PassoOnboarding.playerCard,
    );
  });

  test('tf_acc_08_riprende_scelta_ruolo_dopo_interruzione', () async {
    // Preparazione: l'utente esce dopo la creazione dell'Account, senza scegliere il ruolo.
    // Esito atteso (UC_ACC_1 E3): onboarding in corso, ruolo non scelto e al
    // successivo accesso si ripropone la scelta del ruolo.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);
    final id = await registraUtente(control);
    final account = await repository.findById(id);

    expect(account!.statoOnboarding, StatoOnboarding.inCorso);
    expect(account.ruoloAccount, isNull);
    expect(
      control.passoOnboardingDaRiprendere(account),
      PassoOnboarding.sceltaRuolo,
    );
  });

  test('tf_acc_09_riprende_player_card_dopo_interruzione', () async {
    // Preparazione: il Giocatore esce dalla configurazione senza salvare la
    // Player Card.
    // Esito atteso (UC_ACC_1 E3): ruolo Giocatore definitivo, scheda vuota,
    // onboarding in corso e configurazione da riproporre al successivo accesso.
    final repository = InMemoryAccountRepository();
    final control = creaControl(repository);
    final id = await registraUtente(control);
    await control.confermaRuolo(id);
    final account = await repository.findById(id);

    expect(account, isA<Giocatore>());
    final giocatorePersistito = account! as Giocatore;
    expect(giocatorePersistito.ruoloAccount, RuoloAccount.giocatore);
    expect(giocatorePersistito.statoOnboarding, StatoOnboarding.inCorso);
    expect(giocatorePersistito.ruoloPreferitoInCampo, isNull);
    expect(giocatorePersistito.piedeDominante, isNull);
    expect(
      control.passoOnboardingDaRiprendere(giocatorePersistito),
      PassoOnboarding.playerCard,
    );
  });
}
