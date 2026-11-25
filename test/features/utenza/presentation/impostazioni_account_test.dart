// Widget test di ImpostazioniAccount (KCK-215, RF_ACC_3): test frame di
// logout di docs/test/cp_UC_ACC_1_UC_LEG_1.md (F4, TF_ACC_14) ed errore di
// rete. Control "finto": AutenticazioneControl con un repository in memoria.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kickly/app.dart';
import 'package:kickly/core/errors/app_exception.dart';
import 'package:kickly/core/provider/autenticazione_provider.dart';
import 'package:kickly/core/router/app_router.dart';
import 'package:kickly/features/utenza/data/in_memory_account_repository.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/autenticazione_control.dart';
import 'package:kickly/features/utenza/presentation/impostazioni_account.dart';

const String _email = 'giulia.verdi@example.com';
const String _password = 'PasswordFittizia1!';

/// Repository il cui logout fallisce per un problema di rete.
class _RepositorySenzaRete extends InMemoryAccountRepository {
  @override
  Future<void> esci() async => throw AppException.network();
}

/// Avvia l'app con un utente autenticato su /impostazioni-account.
Future<void> _apriImpostazioni(
  WidgetTester tester,
  InMemoryAccountRepository repository,
) async {
  await repository.createAccount(
    const Account(
      id: '00000000-0000-4000-8000-000000000101',
      ruoloAccount: RuoloAccount.giocatore,
      nome: 'Giulia',
      cognome: 'Verdi',
      email: _email,
      eta: 24,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.completato,
      preferenzeNotifiche: '{}',
    ),
  );
  repository.impostaPassword(_email, _password);
  final AutenticazioneControl control = AutenticazioneControl(
    accountRepository: repository,
  );
  await control.login(_email, _password);
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
  appRouter.router.go('/impostazioni-account');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tf_acc_14_esci_chiude_la_sessione', (tester) async {
    // Preparazione: utente autenticato che sceglie il logout da
    // ImpostazioniAccount.
    // Esito atteso: la sessione viene chiusa e l'app torna alla schermata
    // iniziale; per accedere di nuovo servono le credenziali.
    final InMemoryAccountRepository repository = InMemoryAccountRepository();
    await _apriImpostazioni(tester, repository);
    expect(find.byType(ImpostazioniAccount), findsOneWidget);

    await tester.tap(find.byKey(const Key('impostazioni_account_esci')));
    await tester.pumpAndSettle();

    expect(repository.idAccountAutenticato(), isNull);
    expect(find.byType(SchermataIniziale), findsOneWidget);
    expect(find.byType(ImpostazioniAccount), findsNothing);

    // Senza credenziali la Dashboard non e' piu' raggiungibile.
    GoRouter.of(tester.element(find.byType(SchermataIniziale)))
        .go('/dashboard');
    await tester.pumpAndSettle();
    expect(find.byType(Dashboard), findsNothing);
    expect(find.byType(SchermataIniziale), findsOneWidget);
  });

  testWidgets('un errore di rete nel logout viene mostrato', (tester) async {
    // Preparazione: il servizio non e' raggiungibile durante il logout.
    // Esito atteso: si resta sulle impostazioni con il messaggio di rete.
    await _apriImpostazioni(tester, _RepositorySenzaRete());

    await tester.tap(find.byKey(const Key('impostazioni_account_esci')));
    await tester.pumpAndSettle();

    expect(find.byType(ImpostazioniAccount), findsOneWidget);
    expect(
      find.text('Problema di connessione. Controlla la rete e riprova.'),
      findsOneWidget,
    );
  });

  testWidgets('senza sessione le impostazioni non sono raggiungibili', (
    tester,
  ) async {
    // Preparazione: utente non autenticato che apre la rotta.
    // Esito atteso: il router lo riporta alla schermata iniziale (KCK-194).
    final AppRouter appRouter = AppRouter(
      sessioneProvider: const SessioneNonAutenticata(),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: appRouter.router));

    appRouter.router.go('/impostazioni-account');
    await tester.pumpAndSettle();

    expect(find.byType(SchermataIniziale), findsOneWidget);
  });
}
