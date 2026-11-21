import 'transazione.dart';

/// Contratto di sola lettura per le transazioni economiche.
///
/// Le transazioni sono create e aggiornate dalle Edge Functions lato server:
/// questo contratto evita ogni metodo di scrittura per proteggere DG1 e DG2.
abstract interface class TransazioneRepository {
  /// Cerca una transazione tramite la sua chiave.
  Future<Transazione?> findById(String id);

  /// Restituisce le transazioni associate alla quota indicata.
  Future<List<Transazione>> findByQuota(String quotaId);

  /// Restituisce le transazioni associate alla prenotazione indicata.
  Future<List<Transazione>> findByPrenotazione(String prenotazioneId);

  /// Restituisce gli accrediti associati al Gestore del Campo indicato.
  Future<List<Transazione>> findByGestoreCampo(String gestoreCampoId);

  /// Cerca una transazione tramite il riferimento idempotente esterno.
  Future<Transazione?> findByRiferimentoEsterno(String riferimentoEsterno);
}
