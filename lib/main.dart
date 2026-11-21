// Punto di ingresso dell'app Kickly.
//
// Questo file deve restare il piu' piccolo possibile: legge la
// configurazione, inizializza Supabase e avvia l'app. Tutto il resto (tema,
// rotte, feature) vive in `app.dart` o nei moduli sotto `lib/`, cosi' da
// poterlo testare senza dover lanciare `main()`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/persistence/sessione_secure_storage.dart';
import 'core/provider/autenticazione_provider.dart';

/// Messaggio mostrato quando l'app viene avviata senza `config.json`.
const String messaggioConfigurazioneMancante =
    'Configurazione mancante: avvia con --dart-define-from-file=config.json';

// `main` e' asincrono perche' deve attendere l'inizializzazione di Supabase
// prima di mostrare l'app.
Future<void> main() async {
  // Collega il framework Flutter al motore prima di usare qualsiasi plugin:
  // Supabase.initialize usa plugin (es. lo storage locale della sessione)
  // che richiedono che il binding sia gia' pronto.
  WidgetsFlutterBinding.ensureInitialized();

  // Senza URL o chiave anon non ha senso contattare Supabase: l'avvio
  // fallirebbe con un errore poco chiaro. Mostriamo invece come avviare
  // l'app correttamente, senza crash (succede anche in CI, che non ha
  // config.json).
  if (!isConfigComplete(supabaseUrl, supabaseAnonKey)) {
    runApp(const ConfigurazioneMancanteApp());
    return;
  }

  // Inizializza il client Supabase condiviso (database, login, file) con i
  // valori letti da config.json. Va fatto prima di runApp, cosi' ogni
  // schermata trova il client gia' pronto.
  // Nota: da supabase_flutter 2.18 il parametro `anonKey` e' deprecato e si
  // chiama `publishableKey`; il valore e' lo stesso (la chiave anon /
  // publishable del dashboard), mai la chiave secret / service_role.
  // La sessione di login si salva nel Secure Storage del sistema operativo e
  // non in SharedPreferences, che e' il default (SDD, deployment; KCK-208).
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SessioneSecureStorage(),
    ),
  );

  // Un solo ProviderContainer per tutta l'app: il router legge la sessione
  // dall'adattatore e le Boundary leggono AutenticazioneControl dallo stesso
  // container (KCK-215).
  final ProviderContainer container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: KicklyApp(
        sessioneProvider: container.read(sessioneAutenticazioneProvider),
      ),
    ),
  );
}

/// App minimale mostrata quando manca la configurazione di Supabase.
///
/// Non tocca Supabase: serve solo a spiegare allo sviluppatore come avviare
/// l'app con il proprio `config.json`.
class ConfigurazioneMancanteApp extends StatelessWidget {
  const ConfigurazioneMancanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Kickly',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              messaggioConfigurazioneMancante,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
