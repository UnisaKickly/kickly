import 'partita.dart';

/// Contratto di persistenza per il ciclo di vita delle partite.
///
/// Espone soltanto operazioni di lettura e di aggiornamento di stato/dati:
/// le transizioni critiche sono validate dal relativo Control e dal database.
abstract interface class PartitaRepository {
  /// Cerca una partita tramite la sua chiave.
  Future<Partita?> findById(String id);

  /// Restituisce le partite pubbliche consultabili dagli utenti.
  Future<List<Partita>> findPubbliche();

  /// Restituisce le partite organizzate da un Giocatore.
  Future<List<Partita>> findByGiocatore(String giocatoreId);

  /// Restituisce le partite appartenenti a una lega.
  Future<List<Partita>> findByLega(String legaId);

  /// Crea una partita con lo stato assegnato dal Control.
  Future<Partita> createPartita(Partita partita);

  /// Aggiorna i dati persistiti della partita.
  Future<Partita> updatePartita(Partita partita);

  /// Aggiorna lo stato della partita senza decidere la transizione.
  Future<void> updateStato(String id, String stato);

  /// Elimina una partita tramite la sua chiave.
  Future<void> deletePartita(String id);
}
