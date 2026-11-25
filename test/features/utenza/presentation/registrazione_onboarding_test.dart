// Widget test dei tre passi di UC_ACC_1: il Control finto isola la Boundary
// da Supabase e permette di verificare navigazione, caricamento ed errori.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/giocatore.dart';
import 'package:kickly/features/utenza/domain/registrazione_control.dart';
import 'package:kickly/features/utenza/domain/validatore_password.dart';
import 'package:kickly/features/utenza/presentation/form_onboarding.dart';
import 'package:kickly/features/utenza/presentation/form_player_card.dart';

const String _accountId = '00000000-0000-4000-8000-000000000101';
const Map<String, Object?> _datiOnboarding = {
  'accountId': _accountId,
  'nome': 'Giulia',
  'cognome': 'Verdi',
  'eta': 24,
};

/// Sessione autenticata finta: consente di verificare la destinazione Dashboard.
class _SessioneAutenticata implements SessioneProvider {
  @override
  bool get autenticato => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Control sostituibile, con risposte ed errori configurabili per ogni test.
class _RegistrazioneControlFinto extends RegistrazioneControl {
  /// Crea un Control isolato dalla persistenza esterna.
  _RegistrazioneControlFinto()
    : super(accountRepository: InMemoryAccountRepository());

  Completer<String>? attesaRegistrazione;
  Completer<void>? attesaConfermaRuolo;
  Completer<Giocatore>? attesaSalvataggio;
  Object? erroreRegistrazione;
  Object? erroreConfermaRuolo;
  Object? erroreSalvataggio;
  int registrazioni = 0;
  int confermeRuolo = 0;
  int salvataggiPlayerCard = 0;
  bool accountCreato = false;
  bool onboardingInCorso = false;
  bool ruoloDefinitivo = false;
  bool playerCardSalvata = false;
  PassoOnboarding passoDaRiprendere = PassoOnboarding.nessuno;
  String? nomeRegistrato;
  String? cognomeRegistrato;
  String? emailRegistrata;
  String? passwordRegistrata;
  int? etaRegistrata;
  String? accountIdRuoloConfermato;
  String? accountIdPlayerCard;
  String? ruoloPreferitoSalvato;
  String? piedeDominanteSalvato;

  /// Prepara l'Account autenticato usato dai test che iniziano da un passo
  /// intermedio anziché dal modulo di registrazione.
  void preparaAccount({bool giocatore = false}) {
    accountCreato = true;
    onboardingInCorso = true;
    ruoloDefinitivo = giocatore;
    passoDaRiprendere = giocatore
        ? PassoOnboarding.playerCard
        : PassoOnboarding.sceltaRuolo;
  }

  @override
  Future<String> registra({
    required String? nome,
    required String? cognome,
    required String? email,
    required String? password,
    required int? eta,
  }) async {
    registrazioni++;
    nomeRegistrato = nome;
    cognomeRegistrato = cognome;
    emailRegistrata = email;
    passwordRegistrata = password;
    etaRegistrata = eta;
    late final String accountId;
    if (attesaRegistrazione != null) {
      accountId = await attesaRegistrazione!.future;
    } else {
      if (erroreRegistrazione != null) {
        throw erroreRegistrazione!;
      }
      accountId = _accountId;
    }
    accountCreato = true;
    onboardingInCorso = true;
    ruoloDefinitivo = false;
    playerCardSalvata = false;
    passoDaRiprendere = PassoOnboarding.sceltaRuolo;
    return accountId;
  }

  @override
  Future<void> confermaRuolo(String accountId) async {
    confermeRuolo++;
    accountIdRuoloConfermato = accountId;
    if (attesaConfermaRuolo != null) {
      await attesaConfermaRuolo!.future;
    } else if (erroreConfermaRuolo != null) {
      throw erroreConfermaRuolo!;
    }
    ruoloDefinitivo = true;
    passoDaRiprendere = PassoOnboarding.playerCard;
  }

  @override
  Future<Account?> accountAutenticato() async {
    if (!accountCreato) {
      return null;
    }
    final Map<String, Object?> dati = {
      'id': _accountId,
      'ruoloAccount': ruoloDefinitivo ? RuoloAccount.giocatore : null,
      'nome': nomeRegistrato ?? 'Giulia',
      'cognome': cognomeRegistrato ?? 'Verdi',
      'email': emailRegistrata ?? 'giulia@example.com',
      'eta': etaRegistrata ?? 24,
      'statoAccount': StatoAccount.attivo,
      'statoOnboarding': onboardingInCorso
          ? StatoOnboarding.inCorso
          : StatoOnboarding.completato,
      'preferenzeNotifiche': '{}',
    };
    if (!ruoloDefinitivo) {
      return Account(
        id: dati['id']! as String,
        ruoloAccount: null,
        nome: dati['nome']! as String,
        cognome: dati['cognome']! as String,
        email: dati['email']! as String,
        eta: dati['eta']! as int,
        statoAccount: dati['statoAccount']! as String,
        statoOnboarding: dati['statoOnboarding']! as String,
        preferenzeNotifiche: dati['preferenzeNotifiche']! as String,
      );
    }
    return Giocatore(
      id: dati['id']! as String,
      ruoloAccount: RuoloAccount.giocatore,
      nome: dati['nome']! as String,
      cognome: dati['cognome']! as String,
      email: dati['email']! as String,
      eta: dati['eta']! as int,
      statoAccount: dati['statoAccount']! as String,
      statoOnboarding: dati['statoOnboarding']! as String,
      preferenzeNotifiche: dati['preferenzeNotifiche']! as String,
      ruoloPreferitoInCampo: playerCardSalvata ? ruoloPreferitoSalvato : null,
      piedeDominante: playerCardSalvata ? piedeDominanteSalvato : null,
    );
  }

  @override
  FutureOr<PassoOnboarding> passoOnboardingDaRiprendere([Account? account]) {
    if (account != null) {
      return super.passoOnboardingDaRiprendere(account);
    }
    return passoDaRiprendere;
  }

  @override
  Future<Giocatore> salvaPlayerCard(
    String accountId, {
    required String? ruoloPreferitoInCampo,
    required String? piedeDominante,
  }) async {
    salvataggiPlayerCard++;
    accountIdPlayerCard = accountId;
    ruoloPreferitoSalvato = ruoloPreferitoInCampo;
    piedeDominanteSalvato = piedeDominante;
    late final Giocatore giocatore;
    if (attesaSalvataggio != null) {
      giocatore = await attesaSalvataggio!.future;
    } else {
      if (erroreSalvataggio != null) {
        throw erroreSalvataggio!;
      }
      giocatore = Giocatore(
        id: accountId,
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Giulia',
        cognome: 'Verdi',
        email: 'giulia@example.com',
        eta: 24,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
        ruoloPreferitoInCampo: ruoloPreferitoInCampo,
        piedeDominante: piedeDominante,
      );
    }
    playerCardSalvata = true;
    onboardingInCorso = false;
    passoDaRiprendere = PassoOnboarding.nessuno;
    return giocatore;
  }
}

/// Avvia la rotta di registrazione con il Control finto passato al router.
Future<AppRouter> _apriRegistrazione(
  WidgetTester tester,
  _RegistrazioneControlFinto control,
) async {
  final AppRouter router = AppRouter(
    sessioneProvider: _SessioneAutenticata(),
    registrazioneControl: control,
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.router));
  router.router.go('/registrazione');
  await tester.pumpAndSettle();
  return router;
}

/// Compila i campi UI_2 con dati validi per isolare il caso sotto test.
Future<void> _compilaRegistrazione(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('form_registrazione_nome')),
    'Giulia',
  );
  await tester.enterText(
    find.byKey(const Key('form_registrazione_cognome')),
    'Verdi',
  );
  await tester.enterText(
    find.byKey(const Key('form_registrazione_email')),
    'giulia@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('form_registrazione_password')),
    'PasswordFittizia1!',
  );
  await tester.enterText(find.byKey(const Key('form_registrazione_eta')), '24');
}

/// Avvia UI_3 con i dati già creati e il Control finto.
Future<AppRouter> _apriOnboarding(
  WidgetTester tester,
  _RegistrazioneControlFinto control,
) async {
  control.preparaAccount();
  final AppRouter router = AppRouter(
    sessioneProvider: _SessioneAutenticata(),
    registrazioneControl: control,
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.router));
  router.router.go('/onboarding', extra: _datiOnboarding);
  await tester.pumpAndSettle();
  return router;
}

/// Avvia UI_4 con il Giocatore già confermato.
Future<AppRouter> _apriPlayerCard(
  WidgetTester tester,
  _RegistrazioneControlFinto control,
) async {
  control.preparaAccount(giocatore: true);
  final AppRouter router = AppRouter(
    sessioneProvider: _SessioneAutenticata(),
    registrazioneControl: control,
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router.router));
  router.router.go('/player-card', extra: _datiOnboarding);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  // TF_ACC_01: con dati completi e validi, la registrazione crea l'account
  // attivo con onboarding in corso e avvia la scelta del ruolo; nel frattempo
  // il modulo segnala il caricamento e disabilita la conferma.
  testWidgets('tf_acc_01_registrazioneValida_avviaSceltaRuolo', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..attesaRegistrazione = Completer<String>();
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('form_registrazione_continua')),
          )
          .onPressed,
      isNull,
    );

    control.attesaRegistrazione!.complete(_accountId);
    await tester.pumpAndSettle();

    expect(find.byType(FormOnboarding), findsOneWidget);
    expect(find.text('PASSO 2 DI 3'), findsOneWidget);
    expect(control.registrazioni, 1);
    expect(control.nomeRegistrato, 'Giulia');
    expect(control.cognomeRegistrato, 'Verdi');
    expect(control.emailRegistrata, 'giulia@example.com');
    expect(control.passwordRegistrata, 'PasswordFittizia1!');
    expect(control.etaRegistrata, 24);
    expect(control.accountCreato, isTrue);
    expect(control.onboardingInCorso, isTrue);
    expect(control.passoDaRiprendere, PassoOnboarding.sceltaRuolo);
  });

  // TF_ACC_02: preparando un indirizzo già usato, il sistema mostra l'errore
  // e lascia l'utente nel modulo senza creare l'account, così può riprovare.
  testWidgets('tf_acc_02_emailGiaRegistrata_rimaneInRegistrazione', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = AppException(
        message: 'Email già registrata. Accedi o usa un altro indirizzo email.',
        code: 'email_gia_registrata',
      );
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(
      find.text('Email già registrata. Accedi o usa un altro indirizzo email.'),
      findsOneWidget,
    );
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
    expect(control.onboardingInCorso, isFalse);
  });

  // TF_ACC_03: lasciando vuoto un campo obbligatorio (qui il nome), è atteso
  // l'errore specifico, senza creazione dell'account e restando al passo 3.
  testWidgets('tf_acc_03_campoObbligatorioMancante_rimaneInRegistrazione', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = AppException(
        message: 'Inserisci il nome',
        code: 'campo_obbligatorio',
      );
    await _apriRegistrazione(tester, control);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(find.text('Inserisci il nome'), findsOneWidget);
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
  });

  // TF_ACC_04: con il modulo completo ma password debole, il sistema mostra
  // l'errore specifico; la registrazione non crea l'account e resta al modulo.
  testWidgets('tf_acc_04_passwordDebole_nonCreaAccount', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = PasswordDeboleException();
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La password deve avere almeno 8 caratteri, una lettera e un numero',
      ),
      findsOneWidget,
    );
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
  });

  // Controllo accessorio: un'età non valida riceve il messaggio previsto e
  // l'utente resta nel modulo, senza avanzare all'onboarding.
  testWidgets('eta non valida mostra il messaggio specifico', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = AppException(
        message: "L'età deve essere compresa tra 14 e 120 anni",
        code: 'eta_non_valida',
      );
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(
      find.text("L'età deve essere compresa tra 14 e 120 anni"),
      findsOneWidget,
    );
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
  });

  // Controllo accessorio: un problema di rete in registrazione mostra il
  // messaggio di connessione e non porta fuori dal modulo.
  testWidgets('errore di rete in registrazione mostra il messaggio di rete', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = AppException.network();
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(
      find.text('Problema di connessione. Controlla la rete e riprova.'),
      findsOneWidget,
    );
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
  });

  // Controllo accessorio: un errore inatteso non espone dettagli tecnici e
  // mantiene l'utente nella schermata di registrazione.
  testWidgets('errore sconosciuto mostra il messaggio generico', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreRegistrazione = StateError('dettaglio tecnico da non mostrare');
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    expect(
      find.text('Si è verificato un errore imprevisto. Riprova.'),
      findsOneWidget,
    );
    expect(find.text('dettaglio tecnico da non mostrare'), findsNothing);
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.accountCreato, isFalse);
  });

  // Controllo accessorio: durante la conferma del ruolo la UI segnala
  // l'attesa; a operazione completata apre la configurazione Player Card.
  testWidgets('conferma ruolo mostra il caricamento e apre UI_4', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..attesaConfermaRuolo = Completer<void>();
    await _apriOnboarding(tester, control);

    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('form_onboarding_conferma')),
          )
          .onPressed,
      isNull,
    );

    control.attesaConfermaRuolo!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(FormPlayerCard), findsOneWidget);
    expect(find.text('PASSO 3 DI 3'), findsOneWidget);
    expect(control.confermeRuolo, 1);
  });

  // Controllo richiesto dal ticket: il ruolo Gestore è visibile ma disabilitato,
  // quindi non viene confermato e la schermata di scelta resta aperta.
  testWidgets('Gestore resta visibile ma non disponibile', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto();
    await _apriOnboarding(tester, control);

    expect(find.byKey(const Key('form_onboarding_gestore')), findsOneWidget);
    expect(find.text('Disponibile a breve'), findsOneWidget);
    await tester.tap(find.byKey(const Key('form_onboarding_gestore')));
    await tester.pumpAndSettle();

    expect(find.byType(FormOnboarding), findsOneWidget);
    expect(control.confermeRuolo, 0);
  });

  // Controllo accessorio: un errore di rete scegliendo il ruolo mostra il
  // messaggio previsto e lascia l'utente sulla schermata di onboarding.
  testWidgets('errore di rete nella scelta ruolo resta su UI_3', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreConfermaRuolo = AppException.network();
    await _apriOnboarding(tester, control);

    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pumpAndSettle();

    expect(find.byType(FormOnboarding), findsOneWidget);
    expect(
      find.text('Problema di connessione. Controlla la rete e riprova.'),
      findsOneWidget,
    );
    expect(control.ruoloDefinitivo, isFalse);
  });

  // TF_ACC_05: con Giocatore e Player Card completata, il ruolo è definitivo,
  // la scheda è salvata, l'onboarding è completato e viene mostrata la dashboard.
  testWidgets('tf_acc_05_giocatoreCompletaPlayerCard_apreDashboard', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..attesaSalvataggio = Completer<Giocatore>();
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);
    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();
    expect(find.byType(FormOnboarding), findsOneWidget);

    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pumpAndSettle();
    expect(find.byType(FormPlayerCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('form_player_card_salva')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('form_player_card_salva')))
          .onPressed,
      isNull,
    );

    control.attesaSalvataggio!.complete(
      const Giocatore(
        id: _accountId,
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Giulia',
        cognome: 'Verdi',
        email: 'giulia@example.com',
        eta: 24,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
        ruoloPreferitoInCampo: 'Centrocampista',
        piedeDominante: 'Destro',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dashboard), findsOneWidget);
    expect(control.salvataggiPlayerCard, 1);
    expect(control.registrazioni, 1);
    expect(control.nomeRegistrato, 'Giulia');
    expect(control.cognomeRegistrato, 'Verdi');
    expect(control.emailRegistrata, 'giulia@example.com');
    expect(control.passwordRegistrata, 'PasswordFittizia1!');
    expect(control.etaRegistrata, 24);
    expect(control.confermeRuolo, 1);
    expect(control.ruoloDefinitivo, isTrue);
    expect(control.accountIdRuoloConfermato, _accountId);
    expect(control.accountIdPlayerCard, _accountId);
    expect(control.ruoloPreferitoSalvato, 'Centrocampista');
    expect(control.piedeDominanteSalvato, 'Destro');
    expect(control.playerCardSalvata, isTrue);
    expect(control.onboardingInCorso, isFalse);
    expect(control.passoDaRiprendere, PassoOnboarding.nessuno);
  });

  // TF_ACC_07: con un dato obbligatorio della Player Card mancante, il sistema
  // segnala il campo, resta nella configurazione e non salva la scheda.
  testWidgets('tf_acc_07_playerCardIncompleta_nonSalva', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreSalvataggio = AppException(
        message: 'Seleziona il piede dominante',
        code: 'player_card_incompleta',
      );
    await _apriPlayerCard(tester, control);

    await tester.tap(find.byKey(const Key('form_player_card_salva')));
    await tester.pumpAndSettle();

    expect(find.byType(FormPlayerCard), findsOneWidget);
    expect(find.text('Seleziona il piede dominante'), findsOneWidget);
    expect(control.playerCardSalvata, isFalse);
  });

  // Controllo accessorio: un errore di rete nel salvataggio segnala il problema
  // e mantiene la Player Card aperta senza segnare la scheda come salvata.
  testWidgets('errore di rete nel salvataggio resta su UI_4', (tester) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto()
      ..erroreSalvataggio = AppException.network();
    await _apriPlayerCard(tester, control);

    await tester.tap(find.byKey(const Key('form_player_card_salva')));
    await tester.pumpAndSettle();

    expect(find.byType(FormPlayerCard), findsOneWidget);
    expect(
      find.text('Problema di connessione. Controlla la rete e riprova.'),
      findsOneWidget,
    );
    expect(control.playerCardSalvata, isFalse);
  });

  // Controllo accessorio del percorso completo: account, ruolo e scheda sono
  // confermati una sola volta prima di arrivare alla dashboard.
  testWidgets('il flusso completo registra, conferma e salva una volta', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto();
    await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();
    expect(find.byType(FormOnboarding), findsOneWidget);

    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pumpAndSettle();
    expect(find.byType(FormPlayerCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('form_player_card_salva')));
    await tester.pumpAndSettle();

    expect(find.byType(Dashboard), findsOneWidget);
    expect(control.registrazioni, 1);
    expect(control.confermeRuolo, 1);
    expect(control.salvataggiPlayerCard, 1);
    expect(control.playerCardSalvata, isTrue);
    expect(control.onboardingInCorso, isFalse);
  });

  // TF_ACC_08: dopo la creazione, l'utente interrompe prima di scegliere il
  // ruolo. L'account resta in corso e al successivo accesso si ripropone UI_3.
  testWidgets('tf_acc_08_interruzionePrimaDelRuolo_riproponeScelta', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto();
    final AppRouter router = await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);
    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    // L'uscita interrompe il flusso dopo la creazione; il rientro simula
    // l'accesso successivo al passo che la specifica richiede di riproporre.
    router.router.go('/');
    await tester.pumpAndSettle();
    expect(control.accountCreato, isTrue);
    expect(control.onboardingInCorso, isTrue);
    expect(control.ruoloDefinitivo, isFalse);
    expect(
      await control.passoOnboardingDaRiprendere(),
      PassoOnboarding.sceltaRuolo,
    );

    expect(
      router.router.routeInformationProvider.value.uri.path,
      '/onboarding',
    );
    expect(find.byType(FormOnboarding), findsOneWidget);
    expect(control.registrazioni, 1);
    expect(control.confermeRuolo, 0);
    expect(control.onboardingInCorso, isTrue);
    router.router.dispose();
  });

  // TF_ACC_09: dopo aver scelto Giocatore, l'utente interrompe prima di
  // salvare la Player Card. L'onboarding resta incompleto e al rientro si
  // ripropone UI_4, senza ripetere la registrazione o la scelta del ruolo.
  testWidgets('tf_acc_09_interruzionePrimaDelSalvataggio_riproponePlayerCard', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto();
    await control.registra(
      nome: 'Giulia',
      cognome: 'Verdi',
      email: 'giulia@example.com',
      password: 'PasswordFittizia1!',
      eta: 24,
    );
    final AppRouter router = await _apriOnboarding(tester, control);

    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pumpAndSettle();
    expect(find.byType(FormPlayerCard), findsOneWidget);

    // Simula l'uscita prima di confermare UI_4 e verifica che al successivo
    // accesso il router ricavi il passo corretto senza state.extra.
    router.router.go('/');
    await tester.pumpAndSettle();
    expect(control.onboardingInCorso, isTrue);
    expect(control.ruoloDefinitivo, isTrue);
    expect(control.playerCardSalvata, isFalse);
    expect(
      await control.passoOnboardingDaRiprendere(),
      PassoOnboarding.playerCard,
    );

    expect(
      router.router.routeInformationProvider.value.uri.path,
      '/player-card',
    );
    expect(find.byType(FormPlayerCard), findsOneWidget);
    expect(find.text('Giulia Verdi'), findsOneWidget);
    expect(control.accountCreato, isTrue);
    expect(control.registrazioni, 1);
    expect(control.confermeRuolo, 1);
    expect(control.salvataggiPlayerCard, 0);
    expect(control.onboardingInCorso, isTrue);
    router.router.dispose();
  });

  // Controllo accessorio: tornando indietro tra i passi non si ripetono
  // registrazione o conferma del ruolo.
  testWidgets('indietro conserva registrazione e non riconferma il ruolo', (
    tester,
  ) async {
    final _RegistrazioneControlFinto control = _RegistrazioneControlFinto();
    final AppRouter router = await _apriRegistrazione(tester, control);
    await _compilaRegistrazione(tester);
    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('form_onboarding_indietro')));
    await tester.pumpAndSettle();
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.registrazioni, 1);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('form_onboarding_conferma')));
    await tester.pumpAndSettle();
    expect(find.byType(FormPlayerCard), findsOneWidget);

    await tester.tap(find.byKey(const Key('form_player_card_indietro')));
    await tester.pumpAndSettle();
    expect(find.byType(FormOnboarding), findsOneWidget);
    expect(control.confermeRuolo, 1);

    await tester.tap(find.byKey(const Key('form_onboarding_indietro')));
    await tester.pumpAndSettle();
    expect(find.byType(FormRegistrazione), findsOneWidget);
    expect(control.registrazioni, 1);

    await tester.tap(find.byKey(const Key('form_registrazione_continua')));
    await tester.pumpAndSettle();
    expect(find.byType(FormPlayerCard), findsOneWidget);
    expect(control.confermeRuolo, 1);
    router.router.dispose();
  });
}
