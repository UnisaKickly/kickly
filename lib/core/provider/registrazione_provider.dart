// Provider di RegistrazioneControl (RF_ACC_2).
//
// Collega il repository Supabase al Control nel composition root e lascia alle
// Boundary solo il Control, così i test possono sostituirlo con un finto.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/utenza/data/supabase_account_repository.dart';
import '../../features/utenza/domain/registrazione_control.dart';
import '../persistence/supabase_client_provider.dart';

/// Crea il Control di registrazione e onboarding del Giocatore.
final Provider<RegistrazioneControl> registrazioneControlProvider =
    Provider<RegistrazioneControl>((Ref ref) {
      return RegistrazioneControl(
        accountRepository: SupabaseAccountRepository(
          ref.watch(supabaseClientProvider),
        ),
      );
    });
