// Provider di GestioneLegaControl e dell'id del Giocatore autenticato
// (KCK-249).
//
// Collegano gli strati come autenticazione_provider.dart: creano il
// repository Supabase delle leghe (strato Data), lo passano al Control
// (strato Domain) e lo mettono a disposizione di FormLega e VistaLeghe. Nei
// test si sostituiscono con `overrideWithValue(...)`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/leghe/data/supabase_lega_repository.dart';
import '../../features/leghe/domain/gestione_lega_control.dart';
import '../persistence/supabase_client_provider.dart';
import 'autenticazione_provider.dart';

/// Control di creazione, modifica ed elenco delle leghe (RF_LEG_1).
final Provider<GestioneLegaControl> gestioneLegaControlProvider =
    Provider<GestioneLegaControl>((Ref ref) {
      return GestioneLegaControl(
        legaRepository: SupabaseLegaRepository(
          ref.watch(supabaseClientProvider),
        ),
      );
    });

/// Id del Giocatore con la sessione aperta, null se nessuno ha fatto
/// l'accesso.
///
/// Le Boundary delle leghe lo passano a GestioneLegaControl, che non dipende
/// da Gestione Utenza (component diagram dell'SDD). Lo legge da
/// AutenticazioneControl a ogni richiesta, cosi' segue login e logout.
final Provider<String? Function()> idGiocatoreAutenticatoProvider =
    Provider<String? Function()>((Ref ref) {
      final control = ref.watch(autenticazioneControlProvider);
      return () => control.idAccountAutenticato;
    });
