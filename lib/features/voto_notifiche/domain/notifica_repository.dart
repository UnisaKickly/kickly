import 'notifica.dart';

/// Contratto di persistenza per la consultazione delle notifiche.
///
/// Espone letture e aggiornamento dello stato di lettura, mentre la creazione
/// delle notifiche resta responsabilita' delle procedure lato server.
abstract interface class NotificaRepository {
  /// Cerca una notifica tramite la sua chiave.
  Future<Notifica?> findById(String id);

  /// Restituisce tutte le notifiche indirizzate all'Account indicato.
  Future<List<Notifica>> findByAccount(String accountId);

  /// Restituisce le sole notifiche non lette dell'Account indicato.
  Future<List<Notifica>> findNonLetteByAccount(String accountId);

  /// Aggiorna lo stato di lettura della notifica indicata.
  ///
  /// La policy RLS consente l'operazione solo sulla notifica dello stesso
  /// Account autenticato.
  Future<void> updateStatoLettura(String id, bool statoLettura);
}
