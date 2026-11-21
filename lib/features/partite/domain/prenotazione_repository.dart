import 'prenotazione.dart';

/// Contratto di persistenza per le prenotazioni degli slot dei campi.
///
/// I vincoli sugli slot sovrapposti restano nel database; il repository
/// persiste e recupera soltanto lo stato e gli importi della prenotazione.
abstract interface class PrenotazioneRepository {
  /// Cerca una prenotazione tramite la sua chiave.
  Future<Prenotazione?> findById(String id);

  /// Restituisce la prenotazione associata alla partita.
  Future<Prenotazione?> findByPartita(String partitaId);

  /// Restituisce le prenotazioni di un campo.
  Future<List<Prenotazione>> findByCampo(String campoId);

  /// Crea una prenotazione per una partita e un campo.
  Future<Prenotazione> createPrenotazione(Prenotazione prenotazione);

  /// Aggiorna tutti i dati persistiti della prenotazione.
  Future<Prenotazione> updatePrenotazione(Prenotazione prenotazione);

  /// Aggiorna lo stato del blocco e la relativa scadenza.
  Future<Prenotazione> updateStatoBlocco(
    String id,
    String statoBlocco,
    DateTime? scadenzaBlocco,
  );

  /// Elimina una prenotazione tramite la sua chiave.
  Future<void> deletePrenotazione(String id);
}
