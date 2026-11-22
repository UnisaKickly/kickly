import '../domain/transazione.dart';
import '../domain/transazione_repository.dart';

/// Implementazione in memoria di TransazioneRepository.
///
/// Espone esclusivamente query di sola lettura sui dati iniziali passati nei
/// test: non contiene metodi di scrittura o creazione transazioni.
class InMemoryTransazioneRepository implements TransazioneRepository {
  /// Crea il repository con le transazioni iniziali opzionali.
  InMemoryTransazioneRepository({Iterable<Transazione>? transazioni}) {
    if (transazioni != null) {
      for (final transazione in transazioni) {
        _transazioni[transazione.id] = transazione;
      }
    }
  }

  final Map<String, Transazione> _transazioni = {};

  @override
  /// Recupera la transazione dalla memoria tramite la sua chiave.
  Future<Transazione?> findById(String id) async => _transazioni[id];

  @override
  /// Restituisce le transazioni associate alla quota indicata.
  Future<List<Transazione>> findByQuota(String quotaId) async {
    return _transazioni.values
        .where((transazione) => transazione.quotaId == quotaId)
        .toList();
  }

  @override
  /// Restituisce le transazioni associate alla prenotazione indicata.
  Future<List<Transazione>> findByPrenotazione(String prenotazioneId) async {
    return _transazioni.values
        .where((transazione) => transazione.prenotazioneId == prenotazioneId)
        .toList();
  }

  @override
  /// Restituisce gli accrediti associati al gestore del campo indicato.
  Future<List<Transazione>> findByGestoreCampo(String gestoreCampoId) async {
    return _transazioni.values
        .where((transazione) => transazione.gestoreCampoId == gestoreCampoId)
        .toList();
  }

  @override
  /// Recupera la transazione tramite il riferimento esterno univoco.
  Future<Transazione?> findByRiferimentoEsterno(
    String riferimentoEsterno,
  ) async {
    for (final transazione in _transazioni.values) {
      if (transazione.riferimentoEsterno == riferimentoEsterno) {
        return transazione;
      }
    }
    return null;
  }
}
