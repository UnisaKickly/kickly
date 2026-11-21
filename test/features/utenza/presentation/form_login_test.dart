// Widget test di FormLogin (KCK-215, RF_ACC_3): un test per ogni test frame
// di login di docs/test/cp_UC_ACC_1_UC_LEG_1.md (F3, TF_ACC_10-13), piu' gli
// stati di caricamento ed errore di rete richiesti dal ticket. Esiti attesi
// dai frame e da D16. Control "finto": AutenticazioneControl con un
// repository in memoria, nessun accesso al DB.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/core/provider/autenticazione_provider.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';

const String _email = 'giulia.verdi@example.com';
const String _password = 'PasswordFittizia1!';

/// Account fittizio registrato con onboarding completato.
const Account _account = Account(
  id: '00000000-0000-4000-8000-000000000101',
  ruoloAccount: RuoloAccount.giocatore,
  nome: 'Giulia',
  cognome: 'Verdi',
  email: _email,
  eta: 24,
  statoAccount: StatoAccount.attivo,
  statoOnboarding: StatoOnboarding.completato,
  preferenzeNotifiche: '{}',
);

/// Repository il cui login resta in attesa finche' il test non lo completa.
class _RepositoryLento extends InMemoryAccountRepository {
  final Completer<void> sblocca = Completer<void>();

  @override
  Future<String> accedi(String email, String password) async {
    await sblocca.future;
    return super.accedi(email, password);
  }
}

/// Repository che simula il servizio di autenticazione non raggiungibile.
class _RepositorySenzaRete extends InMemoryAccountRepository {
  @override
  Future<String> accedi(String email, String password) async =>
      throw AppException.network();
}

/// Avvia l'app su /login con il Control dato e restituisce il router.
Future<AppRouter> _apriLogin(
  WidgetTester tester,
  InMemoryAccountRepository repository,
) async {
  await repository.createAccount(_account);
  repository.impostaPassword(_email, _password);
  final AutenticazioneControl control = AutenticazioneControl(
    accountRepository: repository,
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [autenticazioneControlProvider.overrideWithValue(control)],
  );
  addTearDown(container.dispose);
  final AppRouter appRouter = AppRouter(
    sessioneProvider: container.read(sessioneAutenticazioneProvider),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: appRouter.router),
    ),
  );
  appRouter.router.go('/login');
  await tester.pumpAndSettle();
  return appRouter;
}

/// Scrive le credenziali e preme Accedi.
Future<void> _accedi(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byKey(const Key('form_login_email')), email);
  await tester.enterText(
    find.byKey(const Key('form_login_password')),
    password,
  );
  await tester.tap(find.byKey(const Key('form_login_accedi')));
}

/// Errore mostrato sotto il campo con la chiave data (errorText).
String? _erroreDelCampo(WidgetTester tester, String chiave) =>
    tester.widget<TextField>(find.byKey(Key(chiave))).decoration?.errorText;

void main() {
  testWidgets('tf_acc_10_credenziali_corrette_mostra_la_dashboard', (
    tester,
  ) async {
    // Preparazione: account registrato con onboarding completato; email
    // registrata, password corretta, campi inseriti.
    // Esito atteso: l'utente accede e il sistema mostra la Dashboard.
    await _apriLogin(tester, InMemoryAccountRepository());

    await _accedi(tester, email: _email, password: _password);
    await tester.pumpAndSettle();

    expect(find.byType(Dashboard), findsOneWidget);
    expect(find.byType(FormLogin), findsNothing);
  });

  testWidgets('tf_acc_11_email_non_registrata_resta_su_form_login', (
    tester,
  ) async {
    // Preparazione: nessun account con l'email inserita.
    // Esito atteso: l'utente non viene autenticato e resta su FormLogin con
    // il messaggio generico "Email o password non corretti" (D16).
    await _apriLogin(tester, InMemoryAccountRepository());

    await _accedi(tester, email: 'nessuno@example.com', password: _password);
    await tester.pumpAndSettle();

    expect(find.byType(FormLogin), findsOneWidget);
    expect(find.text('Email o password non corretti'), findsOneWidget);
  });

  testWidgets('tf_acc_12_password_errata_resta_su_form_login', (tester) async {
    // Preparazione: account registrato, password sbagliata.
    // Esito atteso: l'utente non viene autenticato e resta su FormLogin con
    // lo stesso messaggio generico di TF_ACC_11 (D16).
    await _apriLogin(tester, InMemoryAccountRepository());

    await _accedi(tester, email: _email, password: 'PasswordSbagliata9!');
    await tester.pumpAndSettle();

    expect(find.byType(FormLogin), findsOneWidget);
    expect(find.text('Email o password non corretti'), findsOneWidget);
  });

  testWidgets('tf_acc_13_campo_vuoto_errore_sul_campo', (tester) async {
    // Preparazione: modulo di login incompleto (prima email vuota, poi
    // password vuota).
    // Esito atteso: l'utente non viene autenticato, resta su FormLogin e
    // vede l'errore sul campo vuoto (D16).
    await _apriLogin(tester, InMemoryAccountRepository());

    await _accedi(tester, email: '', password: _password);
    await tester.pumpAndSettle();
    expect(_erroreDelCampo(tester, 'form_login_email'), "Inserisci l'email");
    expect(_erroreDelCampo(tester, 'form_login_password'), isNull);
    expect(find.byType(FormLogin), findsOneWidget);

    await _accedi(tester, email: _email, password: '');
    await tester.pumpAndSettle();
    expect(
      _erroreDelCampo(tester, 'form_login_password'),
      'Inserisci la password',
    );
    expect(_erroreDelCampo(tester, 'form_login_email'), isNull);
    expect(find.byType(FormLogin), findsOneWidget);
  });

  testWidgets('durante il login il pulsante mostra il caricamento', (
    tester,
  ) async {
    // Preparazione: il servizio di autenticazione risponde in ritardo.
    // Esito atteso: mentre aspetta, il pulsante Accedi e' disabilitato con
    // un indicatore; a risposta arrivata si va alla Dashboard.
    final _RepositoryLento repository = _RepositoryLento();
    await _apriLogin(tester, repository);

    await _accedi(tester, email: _email, password: _password);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final FilledButton pulsante = tester.widget<FilledButton>(
      find.byKey(const Key('form_login_accedi')),
    );
    expect(pulsante.onPressed, isNull);

    repository.sblocca.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Dashboard), findsOneWidget);
  });

  testWidgets('un errore di rete mostra il messaggio di connessione', (
    tester,
  ) async {
    // Preparazione: il servizio di autenticazione non e' raggiungibile.
    // Esito atteso: si resta su FormLogin con il messaggio di rete, non con
    // quello delle credenziali.
    await _apriLogin(tester, _RepositorySenzaRete());

    await _accedi(tester, email: _email, password: _password);
    await tester.pumpAndSettle();

    expect(find.byType(FormLogin), findsOneWidget);
    expect(
      find.text('Problema di connessione. Controlla la rete e riprova.'),
      findsOneWidget,
    );
    expect(find.text('Email o password non corretti'), findsNothing);
  });

  testWidgets('Registrati porta alla registrazione', (tester) async {
    // Preparazione: utente non registrato su FormLogin (UI_7).
    // Esito atteso: "Registrati" apre la registrazione (NP_GIO_1).
    await _apriLogin(tester, InMemoryAccountRepository());

    await tester.tap(find.text('Registrati'));
    await tester.pumpAndSettle();

    expect(find.byType(FormRegistrazione), findsOneWidget);
  });
}
