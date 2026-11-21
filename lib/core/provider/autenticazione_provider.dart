// Provider di AutenticazioneControl e adattatore della sessione per il router
// (KCK-215, commento dei PM 11211 su KCK-208).
//
// Collegano gli strati: creano il repository Supabase (strato Data), lo
// passano al Control (strato Domain) e mettono il Control a disposizione
// delle Boundary e del router. Nei test si sostituisce il Control con
// `autenticazioneControlProvider.overrideWithValue(...)`.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/utenza/data/supabase_account_repository.dart';
import '../../features/utenza/domain/autenticazione_control.dart';
import '../persistence/supabase_client_provider.dart';
import '../router/app_router.dart';

/// Control di login e logout (RF_ACC_3) usato da FormLogin e
/// ImpostazioniAccount.
final Provider<AutenticazioneControl> autenticazioneControlProvider =
    Provider<AutenticazioneControl>((Ref ref) {
      return AutenticazioneControl(
        accountRepository: SupabaseAccountRepository(
          ref.watch(supabaseClientProvider),
        ),
      );
    });

/// Sessione letta dal router, costruita sopra il Control.
final Provider<SessioneAutenticazione> sessioneAutenticazioneProvider =
    Provider<SessioneAutenticazione>((Ref ref) {
      final SessioneAutenticazione sessione = SessioneAutenticazione(
        ref.watch(autenticazioneControlProvider),
      );
      ref.onDispose(sessione.dispose);
      return sessione;
    });

/// Adattatore tra AutenticazioneControl e il router.
///
/// SessioneProvider e' un Listenable (tipo di Flutter), quindi non puo'
/// implementarlo il Control, che sta in domain/ (DG9). Questa classe ascolta
/// `cambiamentiSessione` del Control e avvisa il router a ogni login o
/// logout, cosi' la schermata cambia da sola (KCK-194).
class SessioneAutenticazione extends ChangeNotifier
    implements SessioneProvider {
  /// Crea l'adattatore e inizia ad ascoltare il Control.
  SessioneAutenticazione(this._control) {
    _sottoscrizione = _control.cambiamentiSessione.listen(
      (bool _) => notifyListeners(),
      // Un errore della sessione (es. rinnovo del token fallito) puo' averla
      // chiusa: il router rilegge lo stato.
      onError: (Object _) => notifyListeners(),
    );
  }

  final AutenticazioneControl _control;
  late final StreamSubscription<bool> _sottoscrizione;

  @override
  bool get autenticato => _control.autenticato;

  @override
  /// Smette di ascoltare il Control quando l'app viene chiusa.
  void dispose() {
    unawaited(_sottoscrizione.cancel());
    super.dispose();
  }
}
