// Boundary FormPlayerCard della tabella degli oggetti del RAD: raccoglie il
// ruolo preferito in campo e il piede dominante (UI_4).
//
// Le scelte vengono salvate esclusivamente tramite RegistrazioneControl; il
// completamento riuscito porta alla Dashboard.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/tema_kickly.dart';
import '../domain/account.dart';
import '../domain/registrazione_control.dart';

/// Passo UI_4 che completa la Player Card iniziale del Giocatore.
class FormPlayerCard extends StatefulWidget {
  /// Crea il form con il Control e i dati anagrafici già raccolti.
  const FormPlayerCard({
    super.key,
    required this.control,
    this.accountId,
    this.nome,
    this.cognome,
    this.eta,
  });

  /// Control usato per completare l'onboarding.
  final RegistrazioneControl? control;

  /// Identificativo dell'Account creato e con ruolo Giocatore.
  final String? accountId;

  /// Dati usati per il riepilogo della Player Card.
  final String? nome;
  final String? cognome;
  final int? eta;

  @override
  /// Crea lo stato di selezione, caricamento ed errore.
  State<FormPlayerCard> createState() => _FormPlayerCardState();
}

/// Stato del passo 3/3 e delle scelte iniziali della Player Card.
class _FormPlayerCardState extends State<FormPlayerCard> {
  static const List<String> _ruoli = [
    'Portiere',
    'Difensore',
    'Centrocampista',
    'Attaccante',
  ];
  static const List<String> _piedi = ['Destro', 'Sinistro', 'Ambidestro'];

  String _ruoloPreferito = 'Centrocampista';
  String _piedeDominante = 'Destro';
  bool _caricamento = false;
  String? _errore;
  String? _accountId;
  String? _nome;
  String? _cognome;
  int? _eta;

  @override
  /// Inizializza i dati ricevuti o li recupera per il redirect di ripresa.
  void initState() {
    super.initState();
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

  /// Recupera dal Control i dati anagrafici per il riepilogo di UI_4.
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
            'Account autenticato non disponibile per la Player Card.',
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

  /// Salva le scelte tramite il Control e apre la Dashboard solo se completate.
  Future<void> _salva() async {
    final String? accountId = _accountId;
    if (accountId == null) {
      _mostraErrore(AppException.unexpected().message);
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
      await control.salvaPlayerCard(
        accountId,
        ruoloPreferitoInCampo: _ruoloPreferito,
        piedeDominante: _piedeDominante,
      );
      if (mounted) {
        context.go('/dashboard');
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

  /// Mostra il messaggio leggibile del Control se il salvataggio fallisce.
  void _mostraErrore(String messaggio) {
    if (mounted) {
      setState(() => _errore = messaggio);
    }
  }

  @override
  /// Applica lo stile del RAD alla configurazione della Player Card.
  Widget build(BuildContext context) {
    return Theme(
      data: TemaKickly.crea(),
      child: Builder(builder: _costruisci),
    );
  }

  /// Costruisce riepilogo anagrafico, selettori e azione finale.
  Widget _costruisci(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('form_player_card_indietro'),
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: _caricamento ? null : () => context.pop(),
        ),
        title: const Text('Player card'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _IndicatorePasso(passo: 3),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(child: Text(_iniziali(_nome, _cognome))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nomeGiocatore,
                                  style: tema.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_ruoloPreferito · Piede '
                                  '${_piedeDominante.toLowerCase()} · Livello 1',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _Etichetta('RUOLO PREFERITO IN CAMPO'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ruoli
                        .map(
                          (String ruolo) => _SceltaPillola(
                            chiave: Key('form_player_card_ruolo_$ruolo'),
                            testo: ruolo,
                            selezionato: _ruoloPreferito == ruolo,
                            onTap: _caricamento
                                ? null
                                : () => setState(() {
                                    _ruoloPreferito = ruolo;
                                    _errore = null;
                                  }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  const _Etichetta('PIEDE DOMINANTE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _piedi
                        .map(
                          (String piede) => _SceltaPillola(
                            chiave: Key('form_player_card_piede_$piede'),
                            testo: piede,
                            selezionato: _piedeDominante == piede,
                            onTap: _caricamento
                                ? null
                                : () => setState(() {
                                    _piedeDominante = piede;
                                    _errore = null;
                                  }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Potrai modificare questi attributi in seguito dal tuo '
                    'profilo.',
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
                    key: const Key('form_player_card_salva'),
                    onPressed: _caricamento ? null : _salva,
                    child: _caricamento
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel:
                                  'Salvataggio Player Card in corso',
                            ),
                          )
                        : const Text('Salva e inizia'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _nomeGiocatore {
    final String nome = _nome?.trim() ?? '';
    final String cognome = _cognome?.trim() ?? '';
    final String nomeCompleto = '$nome $cognome'.trim();
    return nomeCompleto.isEmpty ? 'Giocatore' : nomeCompleto;
  }

  /// Ricava le iniziali mostrate nell'avatar della Player Card.
  String _iniziali(String? nome, String? cognome) {
    final String nomePulito = nome?.trim() ?? '';
    final String cognomePulito = cognome?.trim() ?? '';
    final String inizialeNome = nomePulito.isEmpty
        ? ''
        : nomePulito.characters.first.toUpperCase();
    final String inizialeCognome = cognomePulito.isEmpty
        ? ''
        : cognomePulito.characters.first.toUpperCase();
    return '$inizialeNome$inizialeCognome';
  }
}

/// Mostra il titolo accessibile di una sezione del modulo.
class _Etichetta extends StatelessWidget {
  /// Crea un'etichetta con lo stile del mock-up.
  const _Etichetta(this.testo);

  final String testo;

  @override
  /// Mostra l'etichetta della sezione con lo stile del mock-up.
  Widget build(BuildContext context) {
    return Text(testo, style: Theme.of(context).textTheme.labelMedium);
  }
}

/// Rappresenta una scelta della Player Card come pulsante a pillola.
class _SceltaPillola extends StatelessWidget {
  /// Crea una pillola selezionabile con chiave stabile per i test.
  const _SceltaPillola({
    required this.chiave,
    required this.testo,
    required this.selezionato,
    required this.onTap,
  });

  final Key chiave;
  final String testo;
  final bool selezionato;
  final VoidCallback? onTap;

  @override
  /// Disegna la scelta e ne evidenzia lo stato selezionato.
  Widget build(BuildContext context) {
    final ColorScheme colori = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selezionato,
      enabled: onTap != null,
      child: OutlinedButton(
        key: chiave,
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selezionato ? colori.primary : Colors.transparent,
          foregroundColor: selezionato ? colori.onPrimary : colori.onSurface,
          side: BorderSide(
            color: selezionato ? colori.primary : colori.outline,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: Text(testo),
      ),
    );
  }
}

/// Progressione comune ai tre passi di registrazione.
class _IndicatorePasso extends StatelessWidget {
  /// Crea l'indicatore con il passo corrente evidenziato.
  const _IndicatorePasso({required this.passo});

  final int passo;

  @override
  /// Disegna le tre barre di avanzamento con i passi già completati.
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

/// Annuncia gli errori del Control ai lettori di schermo.
class _MessaggioErrore extends StatelessWidget {
  /// Crea il messaggio accessibile.
  const _MessaggioErrore({required this.messaggio});

  final String messaggio;

  @override
  /// Annuncia l'errore del Control senza esporre dettagli tecnici.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          messaggio,
          key: const Key('form_player_card_errore'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
