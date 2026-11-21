// Boundary FormLogin della tabella degli oggetti del RAD (§3.4.4.1.1):
// raccoglie le credenziali per l'accesso (UI_7, RF_ACC_3).
//
// Chiama solo AutenticazioneControl (mai repository o SDK, DG9). Dopo un
// login riuscito non naviga da sola: il router, avvisato dall'adattatore
// SessioneAutenticazione, mostra la Dashboard (KCK-194).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/provider/autenticazione_provider.dart';
import '../domain/autenticazione_control.dart';
import 'stile_mockup.dart';

/// Schermata di accesso con email e password (UI_7).
class FormLogin extends StatefulWidget {
  /// Crea la schermata di accesso.
  const FormLogin({super.key});

  @override
  /// Crea lo stato che conserva campi, caricamento ed errori.
  State<FormLogin> createState() => _FormLoginState();
}

/// Stato di FormLogin: campi, caricamento ed errori del Control.
class _FormLoginState extends State<FormLogin> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// True mentre la richiesta di login e' in corso.
  bool _caricamento = false;

  /// Errore sotto il campo email o password (D16, campo vuoto).
  String? _erroreEmail;
  String? _errorePassword;

  /// Errore generale sopra il pulsante (credenziali, rete, altro).
  String? _erroreGenerale;

  @override
  /// Libera i controller dei campi.
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Invia le credenziali al Control e mostra l'errore specifico se il login
  /// non riesce.
  Future<void> _accedi() async {
    // Il Control si legge solo qui, al momento dell'invio: la schermata si
    // puo' costruire anche senza ProviderScope (test dell'app shell).
    final AutenticazioneControl control = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(autenticazioneControlProvider);

    setState(() {
      _caricamento = true;
      _erroreEmail = null;
      _errorePassword = null;
      _erroreGenerale = null;
    });
    try {
      await control.login(_email.text, _password.text);
    } on CampoObbligatorioException catch (errore) {
      _mostraErrore(() {
        if (errore.campo == CampoObbligatorioException.email) {
          _erroreEmail = errore.message;
        } else {
          _errorePassword = errore.message;
        }
      });
    } on AppException catch (errore) {
      // CredenzialiNonCorretteException ("Email o password non corretti",
      // D16), rete o altro: ogni AppException ha gia' il messaggio per
      // l'utente.
      _mostraErrore(() => _erroreGenerale = errore.message);
    } on Object {
      // Errore non tradotto dal repository: messaggio generico invece di
      // nessun messaggio.
      _mostraErrore(() => _erroreGenerale = AppException.unexpected().message);
    } finally {
      if (mounted) {
        setState(() => _caricamento = false);
      }
    }
  }

  /// Aggiorna gli errori solo se la schermata e' ancora visibile.
  void _mostraErrore(VoidCallback aggiorna) {
    if (mounted) {
      setState(aggiorna);
    }
  }

  @override
  /// Applica lo stile dei mock-up del RAD (sfondo nero, accento #CAFF00).
  Widget build(BuildContext context) {
    return Theme(
      data: temaMockup(),
      child: Builder(builder: _costruisci),
    );
  }

  /// Costruisce UI_7: istruzioni, card con i campi, link e pulsante Accedi.
  Widget _costruisci(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Accesso'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Inserisci le credenziali dell'account con cui ti sei "
                        'registrato.',
                        style: tema.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Etichetta('EMAIL'),
                              TextField(
                                key: const Key('form_login_email'),
                                controller: _email,
                                enabled: !_caricamento,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  hintText: 'marco.rossi@esempio.it',
                                  errorText: _erroreEmail,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _Etichetta('PASSWORD'),
                              TextField(
                                key: const Key('form_login_password'),
                                controller: _password,
                                enabled: !_caricamento,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  errorText: _errorePassword,
                                ),
                                onSubmitted: (_) => _accedi(),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                // Il recupero password (UI_8) e' di KCK-262:
                                // il link e' come nel mock-up ma senza
                                // azione finche' la schermata non esiste.
                                child: TextButton(
                                  onPressed: null,
                                  child: const Text('Password dimenticata?'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_erroreGenerale != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  // liveRegion: lo screen reader annuncia l'errore appena
                  // compare.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _erroreGenerale!,
                      key: const Key('form_login_errore'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tema.colorScheme.error),
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('form_login_accedi'),
                onPressed: _caricamento ? null : _accedi,
                child: _caricamento
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Accesso in corso',
                        ),
                      )
                    : const Text('Accedi'),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Non hai un account?'),
                  TextButton(
                    onPressed: () => context.go('/registrazione'),
                    child: const Text('Registrati'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etichetta in maiuscolo sopra un campo, come in UI_7.
class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  /// Mostra il testo piccolo sopra il campo.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(testo, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
