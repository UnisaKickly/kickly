import 'quota.dart';

/// Contratto di persistenza per le quote individuali delle partecipazioni.
///
/// La creazione e le transizioni della quota appartengono alla logica critica
/// dei pagamenti: il repository mantiene le firme necessarie al Control senza
/// contenere formule economiche o decidere gli esiti del fornitore.
abstract interface class QuotaRepository {
  /// Cerca una quota tramite la sua chiave.
  Future<Quota?> findById(String id);

  /// Legge una quota tramite la sua chiave, come `findById`.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali operazioni di scrittura
  /// restituiscono errore `42501`.
  /// Questo metodo e' pensato per lettura lato client ed Edge Functions con
  /// service role.
  Future<Quota?> leggiQuota(String quotaId);

  /// Cerca l'unica quota associata alla partecipazione indicata.
  Future<Quota?> findByPartecipazione(String partecipazioneId);

  /// Restituisce le quote ancora da versare delle partecipazioni della partita.
  Future<List<Quota>> findDaVersareByPartita(String partitaId);

  /// Conta le quote ancora da versare delle partecipazioni della partita.
  Future<int> countDaVersareByPartita(String partitaId);

  /// Crea una quota con l'importo e il termine stabiliti dal Control.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' pensato esclusivamente
  /// per l'esecuzione lato server / Edge Functions con service role oppure per
  /// testare i Control tramite implementazioni `InMemoryQuotaRepository`.
  Future<Quota> createQuota(Quota quota);

  /// Aggiorna lo stato di versamento della quota indicata.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' pensato esclusivamente
  /// per l'esecuzione lato server / Edge Functions con service role oppure per
  /// testare i Control tramite implementazioni `InMemoryQuotaRepository`.
  Future<void> updateStatoVersamento(String id, String statoVersamento);

  /// Registra il versamento impostando lo stato della quota a `versata`.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' pensato esclusivamente
  /// per l'esecuzione lato server / Edge Functions con service role oppure per
  /// testare i Control tramite implementazioni `InMemoryQuotaRepository`.
  Future<void> registraVersamento(String quotaId);

  /// Elimina la quota solo se e' ancora nello stato da_versare.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' pensato esclusivamente
  /// per l'esecuzione lato server / Edge Functions con service role oppure per
  /// testare i Control tramite implementazioni `InMemoryQuotaRepository`.
  Future<void> deleteDaVersare(String id);

  /// Verifica che tutte le quote della partita siano state versate.
  Future<bool> tutteLeQuoteVersate(String partitaId);
}
