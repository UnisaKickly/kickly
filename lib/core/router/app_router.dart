import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';

/// Espone lo stato minimo di autenticazione richiesto dal router.
///
/// La classe non dipende da SDK esterni, così il guscio può essere testato
/// usando una sessione finta e il servizio di autenticazione può cambiare.
class SessioneProvider {
  /// Crea una sessione con lo stato autenticato indicato.
  const SessioneProvider({this.autenticato = false});

  /// Indica se l'utente dispone di una sessione autenticata.
  final bool autenticato;
}

/// Configura le rotte e impedisce l'accesso alla dashboard senza sessione.
class AppRouter {
  /// Crea il router usando il provider di sessione fornito dall'app o dai test.
  AppRouter({required SessioneProvider sessioneProvider})
    : router = GoRouter(
        initialLocation: '/',
        redirect: (BuildContext context, GoRouterState state) {
          final bool nellaZonaAutenticata =
              state.matchedLocation == '/dashboard';
          final bool nellaSchermataIniziale = state.matchedLocation == '/';

          if (!sessioneProvider.autenticato && nellaZonaAutenticata) {
            return '/';
          }

          if (sessioneProvider.autenticato && nellaSchermataIniziale) {
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
