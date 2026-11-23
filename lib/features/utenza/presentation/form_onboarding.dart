// Boundary FormOnboarding della tabella degli oggetti del RAD: consente di
// scegliere il ruolo prima della configurazione specifica.
//
// In questo ticket solo il percorso Giocatore è implementato; il Gestore resta
// visibile ma non selezionabile fino al ticket KCK-223.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/account.dart';
import '../domain/registrazione_control.dart';
import 'stile_mockup.dart';

/// Passo UI_3 della procedura di registrazione e onboarding.
class FormOnboarding extends StatefulWidget {
  /// Crea la scelta del ruolo con i dati già raccolti e il Control iniettato.
  const FormOnboarding({
    super.key,
    required this.control,
    this.accountId,
    this.nome,
    this.cognome,
    this.eta,
    this.ruoloConfermato = false,
  });

  /// Control usato per confermare il ruolo Giocatore.
  final RegistrazioneControl? control;

  /// Identificativo dell'Account creato dal passo precedente.
  final String? accountId;

  /// Dati anagrafici da conservare durante la navigazione.
  final String? nome;
  final String? cognome;
  final int? eta;

  /// Indica che la scelta definitiva del Giocatore è già stata salvata.
  final bool ruoloConfermato;

  @override
  /// Crea lo stato di caricamento, errore e conferma della schermata.
  State<FormOnboarding> createState() => _FormOnboardingState();
}

/// Stato UI_3: la selezione Giocatore diventa definitiva una sola volta.
class _FormOnboardingState extends State<FormOnboarding> {
  bool _caricamento = false;
  String? _errore;
  bool _ruoloConfermato = false;
  String? _accountId;
  String? _nome;
  String? _cognome;
  int? _eta;

  @override
  /// Copia lo stato del ruolo ricevuto dalla schermata precedente.
  void initState() {
    super.initState();
    _ruoloConfermato = widget.ruoloConfermato;
    _accountId = widget.accountId;
    _nome = widget.nome;
    _cognome = widget.cognome;
    _eta = widget.eta;
    if (_datiAccountMancanti) {
      _caricamento = true;
      unawaited(_caricaAccount());
    }
  }

  bool get _datiAccountMancanti =>
      _accountId == null || _nome == null || _cognome == null || _eta == null;

  /// Recupera dal Control i dati necessari quando la rotta non riceve extra.
  Future<void> _caricaAccount() async {
    try {
      final RegistrazioneControl? control = widget.control;
      if (control == null) {
        throw AppException.configuration();
      }
      final Account? account = await control.accountAutenticato();
      if (account == null) {
        throw AppException.unexpected(
          originalError: StateError(
            'Account autenticato non disponibile per l’onboarding.',
          ),
        );
      }
      if (mounted) {
        setState(() {
          _accountId ??= account.id;
          _nome ??= account.nome;
          _cognome ??= account.cognome;
          _eta ??= account.eta;
        });
      }
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

  /// Conferma il ruolo una sola volta e apre la configurazione Player Card.
  Future<void> _confermaRuolo() async {
    if (_caricamento) {
      return;
    }
    final String? accountId = _accountId;
    if (accountId == null) {
      _mostraErrore(AppException.unexpected().message);
      return;
    }
    if (_ruoloConfermato) {
      await _apriPlayerCard();
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
      await control.confermaRuolo(accountId);
      if (!mounted) {
        return;
      }
      setState(() => _ruoloConfermato = true);
      await _apriPlayerCard();
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

  /// Apre UI_4 lasciando questo passo nello stack per il ritorno senza scritture.
  Future<void> _apriPlayerCard() async {
    await context.push<void>(
      '/player-card',
      extra: {
        'accountId': _accountId,
        'nome': _nome,
        'cognome': _cognome,
        'eta': _eta,
      },
    );
  }

  /// Mostra l'errore prodotto dal Control se la scelta non è stata salvata.
  void _mostraErrore(String messaggio) {
    if (mounted) {
      setState(() => _errore = messaggio);
    }
  }

  @override
  /// Applica lo stile dei mock-up e costruisce il passo 2/3.
  Widget build(BuildContext context) {
    return Theme(
      data: temaMockup(),
      child: Builder(builder: _costruisci),
    );
  }

  /// Costruisce le due opzioni ruolo e il pulsante di conferma.
  Widget _costruisci(BuildContext context) {
    final ThemeData tema = Theme.of(context);
    final Color accento = tema.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('form_onboarding_indietro'),
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: _caricamento
              ? null
              : () => context.pop<bool>(_ruoloConfermato),
        ),
        title: const Text('Scelta del ruolo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _IndicatorePasso(passo: 2),
                  const SizedBox(height: 20),
                  Text(
                    'Il ruolo determina le funzioni disponibili nella tua '
                    'area personale.',
                    style: tema.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _SchedaRuolo(
                    chiave: const Key('form_onboarding_giocatore'),
                    titolo: 'Giocatore',
                    sottotitolo: 'Calcetto · Calciotto · 11 vs 11',
                    descrizione:
                        'Partecipa alle partite, crea leghe tra amici, vota '
                        "l'MVP e accumula statistiche sulla tua player card.",
                    selezionato: true,
                    abilitato: false,
                    coloreBordo: accento,
                  ),
                  const SizedBox(height: 12),
                  _SchedaRuolo(
                    chiave: const Key('form_onboarding_gestore'),
                    titolo: 'Gestore del campo',
                    sottotitolo: 'Centri sportivi · Club',
                    descrizione:
                        'Pubblica i tuoi campi, gestisci gli orari e le tariffe '
                        'e ricevi gli incassi delle prenotazioni.',
                    selezionato: false,
                    abilitato: false,
                    coloreBordo: tema.colorScheme.outline,
                    indicazione: 'Disponibile a breve',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'La scelta determina le autorizzazioni del tuo account e '
                    'non è modificabile in autonomia in seguito.',
                    style: tema.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  if (_errore != null) _MessaggioErrore(messaggio: _errore!),
                  FilledButton(
                    key: const Key('form_onboarding_conferma'),
                    onPressed: _caricamento ? null : _confermaRuolo,
                    child: _caricamento
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Salvataggio del ruolo in corso',
                            ),
                          )
                        : Text(
                            _ruoloConfermato
                                ? 'Continua alla Player Card'
                                : 'Conferma ruolo',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rappresenta una delle opzioni di ruolo mostrate nel mock-up UI_3.
class _SchedaRuolo extends StatelessWidget {
  /// Crea una card interattiva o informativa in base alla disponibilità.
  const _SchedaRuolo({
    required this.chiave,
    required this.titolo,
    required this.sottotitolo,
    required this.descrizione,
    required this.selezionato,
    required this.abilitato,
    required this.coloreBordo,
    this.indicazione,
  });

  final Key chiave;
  final String titolo;
  final String sottotitolo;
  final String descrizione;
  final bool selezionato;
  final bool abilitato;
  final Color coloreBordo;
  final String? indicazione;

  @override
  /// Mostra il ruolo, i dettagli e l'eventuale indicazione di disponibilità.
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: abilitato,
      selected: selezionato,
      child: Card(
        key: chiave,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: coloreBordo),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selezionato
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(sottotitolo),
                    const SizedBox(height: 8),
                    Text(descrizione),
                    if (indicazione != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        indicazione!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progressione comune alle tre schermate di onboarding.
class _IndicatorePasso extends StatelessWidget {
  /// Crea la progressione con il passo corrente evidenziato.
  const _IndicatorePasso({required this.passo});

  final int passo;

  @override
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

/// Annuncia in modo accessibile un errore del Control.
class _MessaggioErrore extends StatelessWidget {
  /// Crea il messaggio live.
  const _MessaggioErrore({required this.messaggio});

  final String messaggio;

  @override
  /// Visualizza il messaggio in una regione annunciata agli screen reader.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          messaggio,
          key: const Key('form_onboarding_errore'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
