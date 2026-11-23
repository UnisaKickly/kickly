// Routing condiviso dell'app Kickly (infrastruttura, KCK-194).
//
// Il router decide quale schermata mostrare in base allo stato della sessione,
// letto da un'interfaccia SessioneProvider: cosi' non dipende da nessun SDK
// esterno (DG9 Portabilita' e modificabilita', SDD v1.4 §1.2) e nei test si
// usa una sessione finta. L'implementazione vera e' SessioneAutenticazione
// (lib/core/provider/autenticazione_provider.dart), sopra AutenticazioneControl.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../features/utenza/domain/registrazione_control.dart';
import '../../features/utenza/presentation/form_onboarding.dart';
import '../../features/utenza/presentation/form_player_card.dart';
import '../../features/utenza/presentation/impostazioni_account.dart';

/// Espone lo stato minimo di autenticazione richiesto dal router.
///
/// E' un'interfaccia: chi la implementa avvisa i listener quando l'utente
/// entra o esce, e il router ricalcola il reindirizzamento (vedi
/// `refreshListenable` in [AppRouter]). Senza l'avviso, dopo il login l'app
/// resterebbe sulla schermata in cui si trova.
abstract interface class SessioneProvider implements Listenable {
  /// Indica se l'utente dispone di una sessione autenticata.
  bool get autenticato;
}

/// Sessione sempre non autenticata, usata finche' non esiste
/// AutenticazioneControl.
///
/// Non cambia mai stato, quindi non ha listener da avvisare. E' `const` per
/// poter essere il valore predefinito di KicklyApp.
class SessioneNonAutenticata implements SessioneProvider {
  /// Crea la sessione non autenticata.
  const SessioneNonAutenticata();

  @override
  bool get autenticato => false;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Configura le rotte e impedisce l'accesso alla dashboard senza sessione.
class AppRouter {
  /// Crea il router usando il provider di sessione fornito dall'app o dai test.
  ///
  /// Il router ascolta [sessioneProvider]: a ogni cambio di sessione rivaluta
  /// la rotta corrente (login -> dashboard, logout -> schermata iniziale).
  AppRouter({
    required SessioneProvider sessioneProvider,
    RegistrazioneControl? registrazioneControl,
  }) : router = GoRouter(
         initialLocation: '/',
         refreshListenable: sessioneProvider,
         redirect: (BuildContext context, GoRouterState state) {
           // Le impostazioni dell'account (logout, KCK-215) sono solo per chi
           // e' autenticato, come la dashboard.
           final bool nellaZonaAutenticata =
               state.matchedLocation == '/dashboard' ||
               state.matchedLocation == '/impostazioni-account';
           // Schermata iniziale e login non servono a chi e' gia' autenticato:
           // dopo il login (RF_ACC_3, UI_7 -> Dashboard) si va alla dashboard.
           // La registrazione e' esclusa perche' dopo di essa l'onboarding di
           // UC_ACC_1 continua (scelta del ruolo, Player Card).
           final bool nellIngressoPubblico =
               state.matchedLocation == '/' ||
               state.matchedLocation == '/login';
           final bool nelFlussoOnboarding =
               state.matchedLocation == '/onboarding' ||
               state.matchedLocation == '/player-card';
           if (!sessioneProvider.autenticato &&
               (nellaZonaAutenticata || nelFlussoOnboarding)) {
             return '/';
           }

           if (sessioneProvider.autenticato &&
               registrazioneControl != null &&
               (nellIngressoPubblico ||
                   state.matchedLocation == '/dashboard' ||
                   nelFlussoOnboarding)) {
             return _destinazioneOnboarding(
               state.matchedLocation,
               registrazioneControl,
             );
           }

           if (sessioneProvider.autenticato && nellIngressoPubblico) {
             return '/dashboard';
           }

           return null;
         },
         routes: [
           GoRoute(
             path: '/',
             builder: (BuildContext context, GoRouterState state) =>
                 const SchermataIniziale(),
           ),
           GoRoute(
             path: '/login',
             builder: (BuildContext context, GoRouterState state) =>
                 const FormLogin(),
           ),
           GoRoute(
             path: '/registrazione',
             builder: (BuildContext context, GoRouterState state) =>
                 FormRegistrazione(control: registrazioneControl),
           ),
           GoRoute(
             path: '/onboarding',
             builder: (BuildContext context, GoRouterState state) {
               final Map<String, Object?>? dati = _datiFlusso(state.extra);
               return FormOnboarding(
                 control: registrazioneControl,
                 accountId: dati?['accountId'] as String?,
                 nome: dati?['nome'] as String?,
                 cognome: dati?['cognome'] as String?,
                 eta: dati?['eta'] as int?,
                 ruoloConfermato: dati?['ruoloConfermato'] == true,
               );
             },
           ),
           GoRoute(
             path: '/player-card',
             builder: (BuildContext context, GoRouterState state) {
               final Map<String, Object?>? dati = _datiFlusso(state.extra);
               return FormPlayerCard(
                 control: registrazioneControl,
                 accountId: dati?['accountId'] as String?,
                 nome: dati?['nome'] as String?,
                 cognome: dati?['cognome'] as String?,
                 eta: dati?['eta'] as int?,
               );
             },
           ),
           GoRoute(
             path: '/impostazioni-account',
             builder: (BuildContext context, GoRouterState state) =>
                 const ImpostazioniAccount(),
           ),
           GoRoute(
             path: '/dashboard',
             builder: (BuildContext context, GoRouterState state) =>
                 const Dashboard(),
           ),
         ],
       );

  /// Router GoRouter pronto per essere collegato a MaterialApp.router.
  final GoRouter router;

  /// Verifica il payload necessario a riprendere i passi di onboarding.
  static Map<String, Object?>? _datiFlusso(Object? extra) {
    if (extra is! Map) {
      return null;
    }
    return {
      if (extra['accountId'] is String) 'accountId': extra['accountId'],
      if (extra['nome'] is String) 'nome': extra['nome'],
      if (extra['cognome'] is String) 'cognome': extra['cognome'],
      if (extra['eta'] is int) 'eta': extra['eta'],
      if (extra['ruoloConfermato'] is bool)
        'ruoloConfermato': extra['ruoloConfermato'],
    };
  }

  /// Risolve il redirect asincrono in base al passo salvato nel Control.
  static Future<String?> _destinazioneOnboarding(
    String rottaCorrente,
    RegistrazioneControl control,
  ) async {
    final PassoOnboarding passo = await control.passoOnboardingDaRiprendere();
    final String destinazione = switch (passo) {
      PassoOnboarding.sceltaRuolo => '/onboarding',
      PassoOnboarding.playerCard => '/player-card',
      PassoOnboarding.nessuno => '/dashboard',
    };
    return rottaCorrente == destinazione ? null : destinazione;
  }
}
