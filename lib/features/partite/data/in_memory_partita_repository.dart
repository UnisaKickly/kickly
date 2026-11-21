import 'package:kickly/core/errors/app_exception.dart';

import '../domain/partita.dart';
import '../domain/partita_repository.dart';

/// Implementazione in memoria di PartitaRepository.
///
/// Offre ricerche deterministiche e UUID fittizi ai test senza usare SDK.
class InMemoryPartitaRepository implements PartitaRepository {
  /// Crea un repository vuoto con ID sequenziali.
  InMemoryPartitaRepository();

  final Map<String, Partita> _partite = {};
  int _nextId = 1;

  /// Genera un UUID fittizio stabile per i test.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Verifica che la partita esista prima di modificare o cancellare.
  void _requirePartita(String id) {
    if (!_partite.containsKey(id)) {
      throw AppException.database(
        message: 'La partita richiesta non esiste.',
        code: '23503',
      );
    }
  }

  @override
  /// Recupera la Partita dalla memoria tramite la sua chiave.
  Future<Partita?> findById(String id) async => _partite[id];

  @override
  /// Restituisce le sole partite pubbliche senza appartenenza a una Lega.
  Future<List<Partita>> findPubbliche() async {
    return _partite.values
        .where(
          (partita) =>
              partita.privacy == PrivacyPartita.pubblica &&
              partita.legaId == null,
        )
        .toList();
  }

  @override
  /// Restituisce le partite organizzate dal Giocatore indicato.
  Future<List<Partita>> findByGiocatore(String giocatoreId) async {
    return _partite.values
        .where((partita) => partita.giocatoreId == giocatoreId)
        .toList();
  }

  @override
  /// Restituisce le partite appartenenti alla Lega indicata.
  Future<List<Partita>> findByLega(String legaId) async {
    return _partite.values
        .where((partita) => partita.legaId == legaId)
        .toList();
  }

  @override
  /// Crea una Partita assegnando un UUID fittizio quando manca l'identificativo.
  Future<Partita> createPartita(Partita partita) async {
    final id = partita.id.isEmpty ? _generateId() : partita.id;
    final created = Partita(
      id: id,
      giocatoreId: partita.giocatoreId,
      legaId: partita.legaId,
      dataOra: partita.dataOra,
      tipologia: partita.tipologia,
      privacy: partita.privacy,
      numPartecipantiRichiesti: partita.numPartecipantiRichiesti,
      stato: partita.stato,
      linkCondivisione: partita.linkCondivisione,
    );
    _partite[id] = created;
    return created;
  }

  @override
  /// Sostituisce i dati della Partita esistente nella memoria del test.
  Future<Partita> updatePartita(Partita partita) async {
    _requirePartita(partita.id);
    _partite[partita.id] = partita;
    return partita;
  }

  @override
  /// Aggiorna lo stato della Partita esistente nella memoria.
  Future<void> updateStato(String id, String stato) async {
    _requirePartita(id);
    final partita = _partite[id]!;
    _partite[id] = Partita(
      id: partita.id,
      giocatoreId: partita.giocatoreId,
      legaId: partita.legaId,
      dataOra: partita.dataOra,
      tipologia: partita.tipologia,
      privacy: partita.privacy,
      numPartecipantiRichiesti: partita.numPartecipantiRichiesti,
      stato: stato,
      linkCondivisione: partita.linkCondivisione,
    );
  }

  @override
  /// Elimina la Partita dalla memoria dopo averne verificato l'esistenza.
  Future<void> deletePartita(String id) async {
    _requirePartita(id);
    _partite.remove(id);
  }
}
