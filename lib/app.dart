import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/tema_kickly.dart';

/// Applica tema e routing condivisi all'app Kickly.
class KicklyApp extends StatefulWidget {
  /// Crea l'app con una sessione non autenticata se non ne viene fornita una.
  const KicklyApp({
    super.key,
    this.sessioneProvider = const SessioneProvider(),
  });

  /// Provider iniettabile per decidere la rotta iniziale dell'app.
  final SessioneProvider sessioneProvider;

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
    _appRouter = AppRouter(sessioneProvider: widget.sessioneProvider);
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

/// Rappresenta provvisoriamente il punto di ingresso al login.
class FormLogin extends StatelessWidget {
  /// Crea il placeholder del form di login.
  const FormLogin({super.key});

  @override
  /// Mostra il placeholder destinato al futuro flusso di accesso.
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Login')));
  }
}

/// Rappresenta provvisoriamente il punto di ingresso alla registrazione.
class FormRegistrazione extends StatelessWidget {
  /// Crea il placeholder del form di registrazione.
  const FormRegistrazione({super.key});

  @override
  /// Mostra il placeholder destinato al futuro flusso di registrazione.
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Registrazione')));
  }
}

/// Rappresenta provvisoriamente la dashboard dell'utente autenticato.
class Dashboard extends StatelessWidget {
  /// Crea il placeholder della dashboard.
  const Dashboard({super.key});

  @override
  /// Mostra il placeholder visibile dopo l'autenticazione.
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}
