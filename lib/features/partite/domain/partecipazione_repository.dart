import 'partecipazione.dart';

/// Contratto di sola lettura per le partecipazioni alle partite.
///
/// Il repository osserva le conferme, ma non registra RSVP: conferma e ritiro
/// presenza sono operazioni server-side riservate alla Edge Function (DG3).
abstract interface class PartecipazioneRepository {
  /// Cerca una partecipazione tramite la sua chiave.
  Future<Partecipazione?> findById(String id);

  /// Restituisce tutte le partecipazioni di una partita.
  Future<List<Partecipazione>> findByPartita(String partitaId);

  /// Restituisce tutte le partecipazioni di un Giocatore.
  Future<List<Partecipazione>> findByGiocatore(String giocatoreId);

  /// Restituisce la risposta univoca di un Giocatore per una partita.
  Future<Partecipazione?> findByGiocatoreEPartita(
    String giocatoreId,
    String partitaId,
  );

  /// Osserva in tempo reale le partecipazioni e i posti disponibili.
  ///
  /// Ogni emissione contiene lo stato corrente letto dalla tabella
  /// `partecipazione`; il canale non espone operazioni di scrittura RSVP.
  Stream<List<Partecipazione>> osservaPartecipazioni(String partitaId);
}
