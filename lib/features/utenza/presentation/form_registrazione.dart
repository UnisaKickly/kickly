// Boundary FormRegistrazione della tabella degli oggetti del RAD:
// raccoglie i dati per creare l'Account prima dell'onboarding.
//
// La schermata conosce solo RegistrazioneControl; l'account appena creato
// resta in memoria durante il percorso per non registrarlo due volte tornando
// indietro da UI_3.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/tema_kickly.dart';
import '../domain/registrazione_control.dart';
import '../domain/validatore_password.dart';

/// Modulo UI_2 per i dati anagrafici, email e password del nuovo Giocatore.
class FormRegistrazione extends StatefulWidget {
  /// Crea il modulo ricevendo il Control dal composition root.
  const FormRegistrazione({super.key, required this.control});

  /// Control usato per la registrazione; null solo nei test della shell vuota.
  final RegistrazioneControl? control;

  @override
  /// Crea lo stato che conserva i campi e il risultato della registrazione.
  State<FormRegistrazione> createState() => _FormRegistrazioneState();
}

/// Stato locale del modulo UI_2.
class _FormRegistrazioneState extends State<FormRegistrazione> {
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _cognome = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _eta = TextEditingController();

  bool _caricamento = false;
  String? _errore;
  String? _accountId;
  bool _ruoloConfermato = false;

  @override
  /// Libera i controller dei campi quando il modulo esce dallo stack.
  void dispose() {
    _nome.dispose();
    _cognome.dispose();
    _email.dispose();
    _password.dispose();
    _eta.dispose();
    super.dispose();
  }

  /// Crea l'Account una volta sola e prosegue al passo di scelta del ruolo.
  Future<void> _continua() async {
    if (_accountId != null) {
      await _apriPassoSuccessivo();
      return;
    }

    final RegistrazioneControl? control = widget.control;
    if (control == null) {
      _mostraErrore(AppException.configuration().message);
      return;
    }

    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final String id = await control.registra(
        nome: _nome.text,
        cognome: _cognome.text,
        email: _email.text,
        password: _password.text,
        eta: int.tryParse(_eta.text),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _accountId = id;
        _password.clear();
      });
      await _apriPassoSuccessivo();
    } on PasswordDeboleException catch (errore) {
      _mostraErrore(errore.message);
    } on AppException catch (errore) {
      _mostraErrore(errore.message);
    } on Object {
      _mostraErrore(AppException.unexpected().message);
    } finally {
      if (mounted) {
        setState(() => _caricamento = false);
      }
    }
  }

  /// Naviga al prossimo passo senza ripetere una registrazione già riuscita.
  Future<void> _apriPassoSuccessivo() async {
    final String? accountId = _accountId;
    if (accountId == null || !mounted) {
      return;
    }
    final Map<String, Object?> dati = {
      'accountId': accountId,
      'nome': _nome.text.trim(),
      'cognome': _cognome.text.trim(),
      'eta': int.tryParse(_eta.text) ?? 0,
    };

    final bool? ruoloConfermato = await context.push<bool>(
      '/onboarding',
      extra: {...dati, 'ruoloConfermato': _ruoloConfermato},
    );
    if (mounted && ruoloConfermato == true) {
      setState(() => _ruoloConfermato = true);
    }
  }

  /// Mostra il messaggio leggibile prodotto dal Control.
  void _mostraErrore(String messaggio) {
    if (mounted) {
      setState(() => _errore = messaggio);
    }
  }

  @override
  /// Applica lo stile scuro del RAD e costruisce il passo 1/3 di UI_2.
  Widget build(BuildContext context) {
    return Theme(
      data: TemaKickly.crea(),
      child: Builder(builder: _costruisci),
    );
  }

  /// Costruisce i campi anagrafici, il messaggio di errore e le azioni.
  Widget _costruisci(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final bool accountCreato = _accountId != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: _caricamento ? null : () => context.go('/'),
        ),
        title: const Text('Registrazione'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _IndicatorePasso(passo: 1),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _campo(
                                  context: context,
                                  controller: _nome,
                                  etichetta: 'NOME',
                                  chiave: 'form_registrazione_nome',
                                  suggerimento: 'Marco',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _campo(
                                  context: context,
                                  controller: _cognome,
                                  etichetta: 'COGNOME',
                                  chiave: 'form_registrazione_cognome',
                                  suggerimento: 'Rossi',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _campo(
                            context: context,
                            controller: _email,
                            etichetta: 'EMAIL',
                            chiave: 'form_registrazione_email',
                            suggerimento: 'marco.rossi@esempio.it',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _campo(
                            context: context,
                            controller: _password,
                            etichetta: 'PASSWORD',
                            chiave: 'form_registrazione_password',
                            obscureText: true,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Almeno 8 caratteri, una lettera e un numero.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          _campo(
                            context: context,
                            controller: _eta,
                            etichetta: 'ETÀ',
                            chiave: 'form_registrazione_eta',
                            suggerimento: '26',
                            keyboardType: TextInputType.number,
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Serve a bilanciare le squadre nelle partite.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "Creando l'account accetti i Termini di servizio e "
                    "l'Informativa privacy.",
                    style: tema.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  if (_errore != null)
                    _MessaggioErrore(
                      chiave: const Key('form_registrazione_errore'),
                      messaggio: _errore!,
                    ),
                  FilledButton(
                    key: const Key('form_registrazione_continua'),
                    onPressed: _caricamento ? null : _continua,
                    child: _caricamento
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Registrazione in corso',
                            ),
                          )
                        : Text(
                            accountCreato
                                ? _ruoloConfermato
                                      ? 'Continua alla Player Card'
                                      : 'Continua onboarding'
                                : 'Crea account',
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _caricamento ? null : () => context.go('/login'),
                    child: const Text('Hai già un account? Accedi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce un campo del modulo con chiave stabile per i widget test.
  Widget _campo({
    required BuildContext context,
    required TextEditingController controller,
    required String etichetta,
    required String chiave,
    String? suggerimento,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(etichetta, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        TextField(
          key: Key(chiave),
          controller: controller,
          enabled: !_caricamento && _accountId == null,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(hintText: suggerimento),
        ),
      ],
    );
  }
}

/// Mostra la progressione 1/3 prevista dai mock-up UI_2, UI_3 e UI_4.
class _IndicatorePasso extends StatelessWidget {
  /// Crea l'indicatore con il passo attivo.
  const _IndicatorePasso({required this.passo});

  final int passo;

  @override
  /// Disegna le barre di avanzamento del flusso di onboarding.
  Widget build(BuildContext context) {
    final Color accento = Theme.of(context).colorScheme.primary;
    final Color bordo = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PASSO $passo DI 3'),
        const SizedBox(height: 8),
        Row(
          children: List<Widget>.generate(
            3,
            (int indice) => Expanded(
              child: Container(
                height: 3,
                margin: EdgeInsets.only(right: indice == 2 ? 0 : 6),
                decoration: BoxDecoration(
                  color: indice < passo ? accento : bordo,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Annuncia gli errori senza nasconderli al lettore di schermo.
class _MessaggioErrore extends StatelessWidget {
  /// Crea un messaggio di errore live.
  const _MessaggioErrore({required this.chiave, required this.messaggio});

  final Key chiave;
  final String messaggio;

  @override
  /// Visualizza e annuncia il messaggio leggibile dal Control.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          messaggio,
          key: chiave,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
