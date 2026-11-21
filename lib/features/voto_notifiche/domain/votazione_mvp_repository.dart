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
  /// In produzione la modifica e' protetta dalle policy RLS C ed e' destinata
  /// all'esecuzione lato server dalle procedure che determinano il vincitore.
  Future<void> updateVincitore(String votazioneId, String? vincitoreId);

  /// Aggiorna lo stato della votazione.
  ///
  /// In produzione la modifica e' protetta dalle policy RLS C ed e' destinata
  /// all'esecuzione lato server dalle procedure che aprono o chiudono il voto.
  Future<void> updateStato(String votazioneId, String statoVotazione);
}
