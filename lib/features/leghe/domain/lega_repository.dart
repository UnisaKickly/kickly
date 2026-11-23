import 'lega.dart';

/// Contratto di persistenza per leghe, membri e amministratori.
///
/// La generazione del codice invito e della relativa scadenza appartiene al
/// Control: il repository salva e recupera soltanto i valori dell'entity.
abstract interface class LegaRepository {
  /// Crea una lega e associa il giocatore creatore come membro e amministratore.
  Future<Lega> createLega(Lega lega, String adminGiocatoreId);

  /// Aggiorna i dati persistiti della lega.
  Future<Lega> updateLega(Lega lega);

  /// Cerca una lega tramite il suo identificativo.
  Future<Lega?> findById(String id);

  /// Cerca una lega tramite il codice invito già generato dal Control.
  Future<Lega?> findByCodiceInvito(String codiceInvito);

  /// Verifica l'unicità normalizzata del nome della lega.
  Future<bool> existsByNome(String nome);

  /// Restituisce le leghe di cui il giocatore è membro.
  Future<List<Lega>> findByGiocatore(String giocatoreId);

  /// Restituisce tutte le leghe pubbliche.
  Future<List<Lega>> findPubbliche();

  /// Aggiunge un membro e, se richiesto, anche come amministratore.
  Future<void> aggiungiMembro(
    String legaId,
    String giocatoreId, {
    bool isAdmin = false,
  });

  /// Rimuove un membro rispettando il vincolo dell'ultimo amministratore.
  Future<void> rimuoviMembro(String legaId, String giocatoreId);

  /// Promuove un membro esistente ad amministratore.
  Future<void> promuoviAdAdmin(String legaId, String giocatoreId);

  /// Dice se il giocatore e' amministratore della lega.
  ///
  /// Serve ai Control per rifiutare le operazioni riservate agli
  /// amministratori (D13); lato server il controllo lo fa anche la RLS.
  Future<bool> isAmministratore(String legaId, String giocatoreId);
}
