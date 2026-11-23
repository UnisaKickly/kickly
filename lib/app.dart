// Widget radice dell'app Kickly (KCK-194).
//
// Collega tema e routing condivisi. Contiene anche le schermate segnaposto
// delle rotte ancora senza Boundary vera (UI_1, UI_2, Dashboard,
// DashboardLega): servono solo a far funzionare la
// navigazione e vanno eliminate da qui quando i ticket dei casi d'uso creano le
// Boundary vere in lib/features/<sottosistema>/presentation/, altrimenti ci
// sarebbero due classi con lo stesso nome.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'features/leghe/domain/lega.dart';
import 'features/utenza/domain/registrazione_control.dart';

// Le Boundary vere restano esportate da app.dart per il router e i test shell.
export 'features/utenza/presentation/form_login.dart' show FormLogin;
export 'features/utenza/presentation/form_registrazione.dart'
    show FormRegistrazione;
import 'core/theme/tema_kickly.dart';

/// Applica tema e routing condivisi all'app Kickly.
class KicklyApp extends StatefulWidget {
  /// Crea l'app con sessione non autenticata e Control opzionale per i test shell.
  const KicklyApp({
    super.key,
    this.sessioneProvider = const SessioneNonAutenticata(),
    this.registrazioneControl,
  });

  /// Sessione iniettabile che decide i reindirizzamenti del router.
  final SessioneProvider sessioneProvider;

  /// Control passato alle Boundary del flusso di registrazione.
  ///
  /// Può essere null solo nelle schermate shell dei test che non eseguono
  /// operazioni di registrazione.
  final RegistrazioneControl? registrazioneControl;

  @override
  /// Crea lo stato che conserva il router per tutta la vita del widget.
  State<KicklyApp> createState() => _KicklyAppState();
}

/// Mantiene una sola istanza del router durante il ciclo di vita dell'app.
class _KicklyAppState extends State<KicklyApp> {
  late final AppRouter _appRouter;

  @override
  /// Costruisce il router una sola volta prima del primo frame.
  void initState() {
    super.initState();
    _appRouter = AppRouter(
      sessioneProvider: widget.sessioneProvider,
      registrazioneControl: widget.registrazioneControl,
    );
  }

  @override
  /// Collega tema e router alla radice Material dell'applicazione.
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kickly',
      debugShowCheckedModeBanner: false,
      theme: TemaKickly.crea(),
      routerConfig: _appRouter.router,
    );
  }
}

/// Mostra l'ingresso pubblico dell'app prima dell'autenticazione.
class SchermataIniziale extends StatelessWidget {
  /// Crea la schermata iniziale.
  const SchermataIniziale({super.key});

  @override
  /// Costruisce il contenuto pubblico mostrato prima dell'autenticazione.
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_soccer, size: 72),
              const SizedBox(height: 16),
              Text('Ciao da Kickly!', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Organizza, gioca, vota, cresci.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rappresenta provvisoriamente la dashboard dell'utente autenticato.
///
/// Segnaposto (sostituito dal ticket della Dashboard):
/// da eliminare quando esiste la Boundary vera.
class Dashboard extends StatelessWidget {
  /// Crea il placeholder della dashboard.
  const Dashboard({super.key});

  @override
  /// Mostra il placeholder visibile dopo l'autenticazione.
  Widget build(BuildContext context) {
    // Il pulsante "Leghe" sostituisce per ora la bottom navigation di
    // UI_LEG_1 (app shell), cosi' la sezione Leghe e' raggiungibile
    // (KCK-249).
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dashboard'),
            TextButton(
              onPressed: () => context.go('/leghe'),
              child: const Text('Leghe'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappresenta provvisoriamente la dashboard di una lega (UI_LEG_3).
///
/// Segnaposto (sostituito da KCK-216, RF_LEG_4): da eliminare quando esiste
/// la Boundary vera. Mostra solo nome e codice d'invito della lega appena
/// creata o modificata (UC_LEG_1 passo 4), ricevuta da FormLega.
class DashboardLega extends StatelessWidget {
  /// Crea il segnaposto per la lega [idLega]; [lega] e' null se la rotta e'
  /// aperta senza i dati (es. link diretto).
  const DashboardLega({super.key, required this.idLega, this.lega});

  /// Id della lega dalla rotta `/leghe/:id`.
  final String idLega;

  /// Lega ricevuta dalla schermata precedente, se c'e'.
  final Lega? lega;

  @override
  /// Mostra nome e codice d'invito, con il ritorno alla sezione Leghe.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/leghe'),
        ),
        title: Text(lega?.nome ?? 'Lega'),
      ),
      body: Center(child: Text('Codice invito: ${lega?.codiceInvito ?? '-'}')),
    );
  }
}
