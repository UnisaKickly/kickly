// Routing condiviso dell'app Kickly (infrastruttura, KCK-194).
//
// Il router decide quale schermata mostrare in base allo stato della sessione,
// letto da un'interfaccia SessioneProvider: cosi' non dipende da nessun SDK
// esterno (DG9 Portabilita' e modificabilita', SDD v1.4 §1.2) e nei test si
// usa una sessione finta. L'implementazione vera la fornira'
// AutenticazioneControl (RF_ACC_3).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';

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
  AppRouter({required SessioneProvider sessioneProvider})
    : router = GoRouter(
        initialLocation: '/',
        refreshListenable: sessioneProvider,
        redirect: (BuildContext context, GoRouterState state) {
          final bool nellaZonaAutenticata =
              state.matchedLocation == '/dashboard';
          // Schermata iniziale e login non servono a chi e' gia' autenticato:
          // dopo il login (RF_ACC_3, UI_7 -> Dashboard) si va alla dashboard.
          // La registrazione e' esclusa perche' dopo di essa l'onboarding di
          // UC_ACC_1 continua (scelta del ruolo, Player Card).
          final bool nellIngressoPubblico =
              state.matchedLocation == '/' || state.matchedLocation == '/login';

          if (!sessioneProvider.autenticato && nellaZonaAutenticata) {
            return '/';
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
                const FormRegistrazione(),
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
}
