// Boundary ImpostazioniAccount della tabella degli oggetti del RAD
// (§3.4.4.1.1): interfaccia che richiama il logout (RF_ACC_3).
//
// Il RAD non ha un mock-up di questa schermata: e' una schermata minima
// nello stile di UI_7 con il solo comando "Esci" (proposta 1 del piano,
// commento 11227 su KCK-215). La cancellazione dell'account e' di un altro
// ticket. Dopo il logout il router torna da solo alla schermata iniziale.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/provider/autenticazione_provider.dart';
import '../domain/autenticazione_control.dart';
import '../../../core/theme/tema_kickly.dart';

/// Impostazioni dell'account con il comando di logout.
class ImpostazioniAccount extends StatefulWidget {
  /// Crea la schermata delle impostazioni.
  const ImpostazioniAccount({super.key});

  @override
  /// Crea lo stato che conserva caricamento ed errore del logout.
  State<ImpostazioniAccount> createState() => _ImpostazioniAccountState();
}

/// Stato di ImpostazioniAccount: caricamento ed errore del logout.
class _ImpostazioniAccountState extends State<ImpostazioniAccount> {
  bool _caricamento = false;
  String? _errore;

  /// Chiede al Control di chiudere la sessione e mostra l'errore se non
  /// riesce (es. rete).
  Future<void> _esci() async {
    final AutenticazioneControl control = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(autenticazioneControlProvider);

    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      await control.logout();
    } on AppException catch (errore) {
      if (mounted) {
        setState(() => _errore = errore.message);
      }
    } on Object {
      // Errore non tradotto dal repository: messaggio generico.
      if (mounted) {
        setState(() => _errore = AppException.unexpected().message);
      }
    } finally {
      if (mounted) {
        setState(() => _caricamento = false);
      }
    }
  }

  @override
  /// Applica lo stile dei mock-up del RAD (sfondo nero, accento #CAFF00).
  Widget build(BuildContext context) {
    return Theme(
      data: TemaKickly.crea(),
      child: Builder(builder: _costruisci),
    );
  }

  /// Costruisce la schermata: titolo, card con il comando Esci ed errore.
  Widget _costruisci(BuildContext context) {
    final ThemeData tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Indietro',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Impostazioni account'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const Key('impostazioni_account_esci'),
                enabled: !_caricamento,
                leading: _caricamento
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Uscita in corso',
                        ),
                      )
                    : const Icon(Icons.logout),
                title: const Text('Esci'),
                subtitle: const Text(
                  'Chiudi la sessione su questo dispositivo: per rientrare '
                  'serviranno email e password.',
                ),
                onTap: _esci,
              ),
            ),
            if (_errore != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _errore!,
                    key: const Key('impostazioni_account_errore'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
