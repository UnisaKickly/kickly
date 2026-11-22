import 'votazione_mvp.dart';

/// Contratto di persistenza per votazioni MVP e preferenze dei votanti.
///
/// Mantiene separata la logica applicativa dall'SDK usato per accedere al
/// database, cosi' il Control puo' leggere e registrare i dati in modo portabile.
abstract interface class VotazioneMVPRepository {
  /// Cerca una votazione tramite la sua chiave.
  Future<VotazioneMVP?> findById(String id);

  /// Cerca l'unica votazione associata alla partita indicata.
  Future<VotazioneMVP?> findByPartita(String partitaId);

  /// Restituisce il giocatore votato dal votante nella votazione indicata.
  ///
  /// Restituisce null quando il votante non ha ancora espresso la preferenza.
  Future<String?> findPreferenzaVotato(String votazioneId, String votanteId);

  /// Registra la preferenza MVP del votante per il giocatore indicato.
  ///
  /// Il vincolo database impedisce un secondo voto dello stesso votante nella
  /// stessa votazione e l'autovoto viene bloccato dal CHECK della migration.
  Future<void> registraPreferenza(
    String votazioneId,
    String votanteId,
    String votatoId,
  );

  /// Aggiorna il vincitore della votazione.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `votazione_mvp`; eventuali scritture dirette da
  /// client restituiscono errore `42501`. Questo metodo e' pensato
  /// esclusivamente per l'esecuzione lato server / Edge Functions con service
  /// role oppure per testare i Control tramite `InMemoryVotazioneMVPRepository`.
  Future<void> updateVincitore(String votazioneId, String? vincitoreId);

  /// Aggiorna lo stato della votazione.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `votazione_mvp`; eventuali scritture dirette da
  /// client restituiscono errore `42501`. Questo metodo e' pensato
  /// esclusivamente per l'esecuzione lato server / Edge Functions con service
  /// role oppure per testare i Control tramite `InMemoryVotazioneMVPRepository`.
  Future<void> updateStato(String votazioneId, String statoVotazione);
}
