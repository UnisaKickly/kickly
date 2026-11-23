// Boundary FormLega della tabella degli oggetti del RAD (§3.4.4.1.2):
// modulo di creazione e di modifica dei dettagli di una lega (UI_LEG_2,
// UC_LEG_1 passi 1-4, RF_LEG_1).
//
// Ordine delle chiamate (non c'e' un sequence diagram):
// creazione: VistaLeghe -> FormLega -> GestioneLegaControl.creaLega() ->
// DashboardLega; modifica: DashboardLega -> FormLega(lega) ->
// GestioneLegaControl.modificaDettagliLega() -> DashboardLega.
// Chiama solo il Control (mai repository o SDK, DG9): la validazione dei
// dati la fa il Control, qui si mostrano solo i suoi errori (E1).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/provider/gestione_lega_provider.dart';
import '../../utenza/presentation/stile_mockup.dart';
import '../domain/gestione_lega_control.dart';
import '../domain/lega.dart';

/// Modulo per creare una lega o modificarne nome, formato e privacy (UI_LEG_2).
///
/// La stessa Boundary serve ai due casi, come dice la tabella degli oggetti:
/// senza [lega] crea una lega nuova, con [lega] ne modifica i dettagli.
class FormLega extends ConsumerStatefulWidget {
  /// Crea il modulo; [lega] e' la lega da modificare, null per crearne una.
  const FormLega({super.key, this.lega});

  /// Lega da modificare; null in creazione.
  final Lega? lega;

  @override
  /// Crea lo stato che conserva campi, caricamento ed errori.
  ConsumerState<FormLega> createState() => _FormLegaState();
}

/// Stato di FormLega: valori dei campi, caricamento ed errori del Control.
class _FormLegaState extends ConsumerState<FormLega> {
  late final TextEditingController _nome;

  /// Tipologia scelta, uno dei valori di [TipologiaMatch].
  late String _tipologiaMatch;

  /// Privacy scelta, uno dei valori di [PrivacyLega].
  late String _privacy;

  /// True mentre la richiesta al Control e' in corso.
  bool _caricamento = false;

  /// Errori sotto i singoli campi (E1: "evidenzia i campi da correggere").
  String? _erroreNome;
  String? _erroreTipologia;
  String? _errorePrivacy;

  /// Errore generale sopra il pulsante (rete, permesso, altro).
  String? _erroreGenerale;

  /// True se il modulo modifica una lega esistente.
  bool get _inModifica => widget.lega != null;

  @override
  /// Precompila i campi con la lega da modificare o con i valori iniziali.
  ///
  /// In creazione la privacy parte da Privata, come l'esempio del passo 3
  /// di UC_LEG_1; il formato da 5 vs 5, primo dell'elenco di RF_LEG_1.
  void initState() {
    super.initState();
    final Lega? lega = widget.lega;
    _nome = TextEditingController(text: lega?.nome ?? '');
    _tipologiaMatch = lega?.tipologiaMatch ?? TipologiaMatch.cinqueVsCinque;
    _privacy = lega?.privacy ?? PrivacyLega.privata;
  }

  @override
  /// Libera il controller del nome.
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  /// Invia i dati al Control e, se va bene, apre la dashboard della lega.
  ///
  /// Ogni eccezione del Control ha un messaggio specifico: gli errori dei
  /// dati vanno sotto il campo, gli altri sopra il pulsante. In caso di
  /// errore si resta sul modulo con i dati inseriti (E1, "rimanendo al
  /// passo 2").
  Future<void> _invia() async {
    final GestioneLegaControl control = ref.read(gestioneLegaControlProvider);
    final String? idGiocatore = ref.read(idGiocatoreAutenticatoProvider)();

    setState(() {
      _caricamento = true;
      _erroreNome = null;
      _erroreTipologia = null;
      _errorePrivacy = null;
      _erroreGenerale = null;
    });
    if (idGiocatore == null) {
      _mostraErrore(
        () => _erroreGenerale = 'Sessione scaduta: accedi di nuovo',
      );
      return;
    }

    try {
      final Lega? lega = widget.lega;
      final Lega salvata = lega == null
          ? await control.creaLega(
              nome: _nome.text,
              tipologiaMatch: _tipologiaMatch,
              privacy: _privacy,
              idGiocatore: idGiocatore,
            )
          : await control.modificaDettagliLega(
              idLega: lega.id,
              nome: _nome.text,
              tipologiaMatch: _tipologiaMatch,
              privacy: _privacy,
              idGiocatore: idGiocatore,
            );
      if (!mounted) return;
      _vaiAllaDashboard(salvata);
    } on DatiLegaNonValidiException catch (errore) {
      _mostraErrore(() => _assegnaErroreCampo(errore.campo, errore.message));
    } on NomeLegaGiaInUsoException catch (errore) {
      // E1 e D17: nome gia' in uso, si evidenzia il campo nome.
      _mostraErrore(() => _assegnaErroreCampo(errore.campo, errore.message));
    } on AppException catch (errore) {
      // OperazioneNonPermessaException (D13), rete, database: ogni
      // AppException ha gia' il messaggio per l'utente.
      _mostraErrore(() => _erroreGenerale = errore.message);
    } on Object {
      // Errore non previsto: messaggio generico, senza dettagli tecnici.
      _mostraErrore(
        () => _erroreGenerale = 'Si e\' verificato un errore. Riprova.',
      );
    }
  }

  /// Mette l'errore sotto il campo indicato dal Control.
  void _assegnaErroreCampo(String campo, String messaggio) {
    switch (campo) {
      case DatiLegaNonValidiException.nome:
        _erroreNome = messaggio;
      case DatiLegaNonValidiException.tipologiaMatch:
        _erroreTipologia = messaggio;
      default:
        _errorePrivacy = messaggio;
    }
  }

  /// Toglie il caricamento e applica l'errore, se la schermata e' ancora
  /// aperta.
  void _mostraErrore(VoidCallback assegna) {
    if (!mounted) return;
    setState(() {
      _caricamento = false;
      assegna();
    });
  }

  /// Apre la dashboard della lega appena creata o modificata (passo 4).
  ///
  /// `go` sostituisce la pila: tornando indietro dalla dashboard non si
  /// rivede il modulo gia' inviato.
  void _vaiAllaDashboard(Lega lega) {
    context.go('/leghe/${lega.id}', extra: lega);
  }

  /// Chiude il modulo senza salvare (exit condition on failure: nessuna
  /// modifica ai dati).
  void _chiudi() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/leghe');
    }
  }

  /// Etichetta di un formato come nei mock-up: "5v5" -> "5 vs 5".
  static String etichettaFormato(String tipologiaMatch) =>
      tipologiaMatch.replaceFirst('v', ' vs ');

  /// Descrizione del formato scelto (UI_LEG_2): giocatori in campo per
  /// partita, cioe' il doppio dei giocatori per squadra.
  static String descrizioneFormato(String tipologiaMatch) {
    final int perSquadra = int.parse(tipologiaMatch.split('v').first);
    return 'Calcio a $perSquadra: ${perSquadra * 2} giocatori per partita.';
  }

  @override
  /// Costruisce il modulo con lo stile dei mock-up del RAD.
  Widget build(BuildContext context) {
    return Theme(
      data: temaMockup(),
      child: Builder(
        builder: (BuildContext context) {
          final TextTheme testo = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Chiudi',
                icon: const Icon(Icons.close),
                onPressed: _caricamento ? null : _chiudi,
              ),
              title: Text(_inModifica ? 'Modifica lega' : 'Crea lega'),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _inModifica
                        ? 'Aggiorna i dettagli della lega. Il codice '
                              'd\'invito resta lo stesso.'
                        : 'Imposta i dettagli della lega. Al termine '
                              'riceverai un codice d\'invito da condividere '
                              'con i membri.',
                    style: testo.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _etichetta('NOME DELLA LEGA', testo),
                          TextField(
                            key: const Key('form_lega_nome'),
                            controller: _nome,
                            enabled: !_caricamento,
                            // Limite di UI_LEG_2; lo ricontrolla il Control.
                            maxLength: GestioneLegaControl.lunghezzaMassimaNome,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: ColoriMockup.testo),
                            decoration: InputDecoration(
                              hintText: 'Champions del Giovedì',
                              helperText:
                                  'Massimo '
                                  '${GestioneLegaControl.lunghezzaMassimaNome}'
                                  ' caratteri, modificabile in seguito.',
                              // Il contatore "n/30" non c'e' nel mock-up.
                              counterText: '',
                              errorText: _erroreNome,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _etichetta('FORMATO MATCH', testo),
                          _sceltaFormato(),
                          const SizedBox(height: 8),
                          Text(
                            _erroreTipologia ??
                                descrizioneFormato(_tipologiaMatch),
                            style: TextStyle(
                              fontSize: 12,
                              color: _erroreTipologia == null
                                  ? ColoriMockup.testoSecondario
                                  : ColoriMockup.errore,
                            ),
                          ),
                          const Divider(height: 32, color: ColoriMockup.bordo),
                          _interruttorePrivacy(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_erroreGenerale != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _erroreGenerale!,
                          key: const Key('form_lega_errore'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: ColoriMockup.errore),
                        ),
                      ),
                    FilledButton(
                      key: const Key('form_lega_invia'),
                      onPressed: _caricamento ? null : _invia,
                      child: _caricamento
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              _inModifica
                                  ? 'Salva modifiche'
                                  : 'Crea lega e genera invito',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Etichetta maiuscola sopra un campo, come nei mock-up.
  Widget _etichetta(String testo, TextTheme stile) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(testo, style: stile.labelMedium),
  );

  /// Pulsanti a pillola dei formati di RF_LEG_1 (UI_LEG_2).
  ///
  /// Mostra tutti i valori di [TipologiaMatch], compreso 10 vs 10 che il
  /// mock-up non ha: prevale il requisito (piano approvato, D4).
  Widget _sceltaFormato() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final String formato in TipologiaMatch.valori)
          ChoiceChip(
            key: Key('form_lega_formato_$formato'),
            label: Text(etichettaFormato(formato)),
            selected: _tipologiaMatch == formato,
            showCheckmark: false,
            shape: const StadiumBorder(
              side: BorderSide(color: ColoriMockup.bordo),
            ),
            backgroundColor: ColoriMockup.card,
            selectedColor: ColoriMockup.accento,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: _tipologiaMatch == formato
                  ? Colors.black
                  : ColoriMockup.testo,
            ),
            onSelected: _caricamento
                ? null
                : (bool _) => setState(() => _tipologiaMatch = formato),
          ),
      ],
    );
  }

  /// Interruttore "Lega privata" (UI_LEG_2): spento = lega pubblica (A1).
  Widget _interruttorePrivacy() {
    final bool privata = _privacy == PrivacyLega.privata;
    return SwitchListTile(
      key: const Key('form_lega_privacy'),
      contentPadding: EdgeInsets.zero,
      value: privata,
      activeThumbColor: Colors.black,
      activeTrackColor: ColoriMockup.accento,
      onChanged: _caricamento
          ? null
          : (bool valore) => setState(
              () => _privacy = valore
                  ? PrivacyLega.privata
                  : PrivacyLega.pubblica,
            ),
      title: Text(
        privata ? 'Lega privata' : 'Lega pubblica',
        style: const TextStyle(
          color: ColoriMockup.testo,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _errorePrivacy ??
            (privata
                ? 'L\'accesso è consentito solo tramite il codice invito o '
                      'il link condiviso dall\'amministratore.'
                : 'La lega è visibile nella ricerca e chiunque può unirsi '
                      'anche senza codice d\'invito.'),
        style: TextStyle(
          color: _errorePrivacy == null
              ? ColoriMockup.testoSecondario
              : ColoriMockup.errore,
        ),
      ),
    );
  }
}
