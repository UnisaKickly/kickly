import 'quota.dart';

/// Contratto di persistenza per le quote individuali delle partecipazioni.
///
/// La creazione e le transizioni della quota appartengono alla logica critica
/// dei pagamenti: il repository mantiene le firme necessarie al Control senza
/// contenere formule economiche o decidere gli esiti del fornitore.
abstract interface class QuotaRepository {
  /// Cerca una quota tramite la sua chiave.
  Future<Quota?> findById(String id);

  /// Cerca l'unica quota associata alla partecipazione indicata.
  Future<Quota?> findByPartecipazione(String partecipazioneId);

  /// Restituisce le quote ancora da versare delle partecipazioni della partita.
  Future<List<Quota>> findDaVersareByPartita(String partitaId);

  /// Conta le quote ancora da versare delle partecipazioni della partita.
  Future<int> countDaVersareByPartita(String partitaId);

  /// Crea una quota con l'importo e il termine stabiliti dal Control.
  ///
  /// In produzione la scrittura e' vincolata dalle policy RLS C e dalle Edge
  /// Functions per preservare i vincoli di sicurezza DG1 e DG2.
  Future<Quota> createQuota(Quota quota);

  /// Aggiorna lo stato di versamento della quota indicata.
  ///
  /// In produzione il passaggio a versata, rimborsata o da_versare e' vincolato
  /// dalle policy RLS C e dalle Edge Functions per DG1 e DG2.
  Future<void> updateStatoVersamento(String id, String statoVersamento);

  /// Elimina la quota solo se e' ancora nello stato da_versare.
  ///
  /// In produzione l'eliminazione e' vincolata dalle policy RLS C e dalle Edge
  /// Functions, perche' una quota gia' versata non puo' essere rimossa dal client.
  Future<void> deleteDaVersare(String id);

  /// Verifica che tutte le quote della partita siano state versate.
  Future<bool> tutteLeQuoteVersate(String partitaId);
}
