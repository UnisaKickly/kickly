// Widget radice dell'app Kickly.
//
// E' volutamente minimale ("hello world"): serve solo come base di partenza
// per il team, per verificare che l'ambiente di sviluppo e la CI funzionino.
// La vera struttura dell'app (routing, state management, feature) verra'
// definita nello Sprint 0/2 e documentata nell'SDD e nell'ODD.
import 'package:flutter/material.dart';

/// Applicazione Kickly: configura tema e schermata iniziale.
class KicklyApp extends StatelessWidget {
  const KicklyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kickly',
      // Nasconde il banner "DEBUG" in alto a destra.
      debugShowCheckedModeBanner: false,
      // Tema Material 3 generato da un unico colore seme (verde "campo da
      // calcio"): il team potra' sostituirlo con il design system definito
      // nei mock-up del RAD.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B8A3A)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Schermata di benvenuto provvisoria.
///
/// Verra' sostituita dal flusso di login/onboarding (Epic "Login e
/// onboarding").
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
