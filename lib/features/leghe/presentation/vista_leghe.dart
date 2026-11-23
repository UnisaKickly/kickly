// Boundary VistaLeghe della tabella degli oggetti del RAD (§3.4.4.1.2):
// sezione "Leghe" con l'elenco delle leghe a cui il Giocatore e' iscritto
// (UI_LEG_1) e l'ingresso a "Crea lega" (UC_LEG_1 passo 1).
//
// Ordine delle chiamate: VistaLeghe -> GestioneLegaControl.visualizzaLeghe()
// -> LegaRepository.findByGiocatore() / isAmministratore(). Chiama solo il
// Control (DG9). "Unisciti" (FormAdesioneLega) e la ricerca delle leghe
// pubbliche sono di KCK-199; membri, prossima gara e convocazioni di UI_LEG_1
// sono dati di RF_LEG_4 e delle partite, non ancora disponibili.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/provider/gestione_lega_provider.dart';
import '../../utenza/presentation/stile_mockup.dart';
import '../domain/lega.dart';

/// Sezione "Leghe" con le leghe del Giocatore (UI_LEG_1).
class VistaLeghe extends ConsumerStatefulWidget {
  /// Crea la sezione "Leghe".
  const VistaLeghe({super.key});

  @override
  /// Crea lo stato che conserva elenco, caricamento ed errore.
  ConsumerState<VistaLeghe> createState() => _VistaLegheState();
}

/// Stato di VistaLeghe: elenco caricato dal Control, caricamento ed errore.
class _VistaLegheState extends ConsumerState<VistaLeghe> {
  /// Leghe del Giocatore con il suo ruolo; null finche' non sono caricate.
  List<({Lega lega, bool amministratore})>? _leghe;

  /// True mentre la richiesta al Control e' in corso.
  bool _caricamento = true;

  /// Messaggio dell'ultimo errore di caricamento, null se non ce n'e'.
  String? _errore;

  @override
  /// Carica l'elenco appena la schermata si apre.
  void initState() {
    super.initState();
    _caricaLeghe();
  }

  /// Chiede al Control le leghe del Giocatore e aggiorna la schermata.
  ///
  /// In caso di errore (es. rete) mostra il messaggio dell'eccezione e il
  /// pulsante "Riprova", che richiama questo metodo.
  Future<void> _caricaLeghe() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    final String? idGiocatore = ref.read(idGiocatoreAutenticatoProvider)();
    try {
      if (idGiocatore == null) {
        throw AppException(
          message: 'Sessione scaduta: accedi di nuovo',
          code: 'sessione_assente',
        );
      }
      final List<({Lega lega, bool amministratore})> leghe = await ref
          .read(gestioneLegaControlProvider)
          .visualizzaLeghe(idGiocatore);
      if (!mounted) return;
      setState(() {
        _leghe = leghe;
        _caricamento = false;
      });
    } on AppException catch (errore) {
      _mostraErrore(errore.message);
    } on Object {
      _mostraErrore('Si e\' verificato un errore. Riprova.');
    }
  }

  /// Toglie il caricamento e mostra l'errore, se la schermata e' aperta.
  void _mostraErrore(String messaggio) {
    if (!mounted) return;
    setState(() {
      _caricamento = false;
      _errore = messaggio;
    });
  }

  /// Apre FormLega in creazione (UC_LEG_1 passo 1, "Crea Nuova Lega").
  void _apriCreazione() => context.push('/leghe/nuova');

  /// Apre la dashboard della lega selezionata (DashboardLega, KCK-216).
  void _apriLega(Lega lega) => context.push('/leghe/${lega.id}', extra: lega);

  @override
  /// Costruisce la sezione con lo stile dei mock-up del RAD.
  Widget build(BuildContext context) {
    return Theme(
      data: temaMockup(),
      child: Builder(
        builder: (BuildContext context) {
          final TextTheme testo = Theme.of(context).textTheme;
          return Scaffold(
            appBar: AppBar(title: const Text('Leghe')),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('vista_leghe_crea'),
                          onPressed: _apriCreazione,
                          child: const Text('Crea lega'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        // FormAdesioneLega arriva con KCK-199: finche' non
                        // c'e' il comando resta visibile ma disattivato.
                        child: OutlinedButton(
                          key: const Key('vista_leghe_unisciti'),
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: ColoriMockup.bordo),
                            foregroundColor: ColoriMockup.testo,
                          ),
                          child: const Text('Unisciti'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('PARTECIPAZIONI ATTIVE', style: testo.labelMedium),
                  const SizedBox(height: 12),
                  ..._contenuto(testo),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Contenuto sotto il titolo: caricamento, errore, lista vuota o leghe.
  List<Widget> _contenuto(TextTheme testo) {
    if (_caricamento) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_errore != null) {
      return [
        Text(
          _errore!,
          key: const Key('vista_leghe_errore'),
          style: const TextStyle(color: ColoriMockup.errore),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _caricaLeghe,
            child: const Text('Riprova'),
          ),
        ),
      ];
    }
    final List<({Lega lega, bool amministratore})> leghe = _leghe ?? const [];
    if (leghe.isEmpty) {
      return [
        Text(
          'Non sei ancora iscritto a nessuna lega. Creane una o unisciti '
          'con un codice d\'invito.',
          style: testo.bodyLarge,
        ),
      ];
    }
    return [
      for (final voce in leghe)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _cardLega(voce.lega, voce.amministratore),
        ),
    ];
  }

  /// Card di una lega come in UI_LEG_1: nome, badge del ruolo, formato e
  /// privacy.
  Widget _cardLega(Lega lega, bool amministratore) {
    final String privacy = lega.privacy == PrivacyLega.privata
        ? 'Privata'
        : 'Pubblica';
    final String perSquadra = lega.tipologiaMatch.split('v').first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('vista_leghe_lega_${lega.id}'),
        onTap: () => _apriLega(lega),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lega.nome,
                      style: const TextStyle(
                        color: ColoriMockup.testo,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    amministratore ? 'ADMIN' : 'MEMBRO',
                    style: const TextStyle(
                      color: ColoriMockup.testoSecondario,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Calcio a $perSquadra · $privacy',
                style: const TextStyle(color: ColoriMockup.testoSecondario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
