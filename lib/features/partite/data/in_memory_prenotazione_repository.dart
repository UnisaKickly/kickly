import 'package:kickly/core/errors/app_exception.dart';

import '../domain/prenotazione.dart';
import '../domain/prenotazione_repository.dart';

/// Implementazione in memoria di PrenotazioneRepository.
///
/// Replica la chiave unica per partita e il rifiuto degli slot attivi
/// sovrapposti, mantenendo i test indipendenti da PostgreSQL.
class InMemoryPrenotazioneRepository implements PrenotazioneRepository {
  /// Crea un repository vuoto con ID sequenziali.
  InMemoryPrenotazioneRepository();

  final Map<String, Prenotazione> _prenotazioni = {};
  int _nextId = 1;

  /// Genera un UUID fittizio stabile per i test.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Verifica che esista una prenotazione prima di modificarla.
  void _requirePrenotazione(String id) {
    if (!_prenotazioni.containsKey(id)) {
      throw AppException.database(
        message: 'La prenotazione richiesta non esiste.',
        code: '23503',
      );
    }
  }

  /// Restituisce le estremita' di uno slot nel formato della migration.
  List<DateTime> _estremi(String intervallo) {
    final parts = intervallo.split('/');
    if (parts.length != 2) return [];
    return [DateTime.parse(parts[0]), DateTime.parse(parts[1])];
  }

  /// Verifica sovrapposizioni semiaperte tra prenotazioni attive dello stesso campo.
  bool _slotSovrapposto(Prenotazione nuova) {
    if (nuova.statoBlocco != 'bloccato' && nuova.statoBlocco != 'confermato') {
      return false;
    }
    final estremiNuovi = _estremi(nuova.intervallo);
    if (estremiNuovi.length != 2) return false;
    for (final esistente in _prenotazioni.values) {
      if (esistente.id == nuova.id ||
          esistente.campoId != nuova.campoId ||
          (esistente.statoBlocco != 'bloccato' &&
              esistente.statoBlocco != 'confermato')) {
        continue;
      }
      final estremiEsistenti = _estremi(esistente.intervallo);
      if (estremiEsistenti.length == 2 &&
          estremiNuovi[0].isBefore(estremiEsistenti[1]) &&
          estremiEsistenti[0].isBefore(estremiNuovi[1])) {
        return true;
      }
    }
    return false;
  }

  /// Impedisce duplicati per partita e slot sovrapposti sullo stesso campo.
  void _validate(Prenotazione prenotazione) {
    if (_prenotazioni.values.any(
      (esistente) =>
          esistente.id != prenotazione.id &&
          esistente.partitaId == prenotazione.partitaId,
    )) {
      throw AppException.database(
        message: 'La partita ha gia\' una prenotazione.',
        code: '23505',
      );
    }
    if (_slotSovrapposto(prenotazione)) {
      throw AppException.database(
        message: 'Lo slot del campo e\' gia\' occupato.',
        code: '23P01',
      );
    }
  }

  @override
  /// Recupera la Prenotazione dalla memoria tramite la sua chiave.
  Future<Prenotazione?> findById(String id) async => _prenotazioni[id];

  @override
  /// Restituisce la Prenotazione associata alla Partita indicata.
  Future<Prenotazione?> findByPartita(String partitaId) async {
    for (final prenotazione in _prenotazioni.values) {
      if (prenotazione.partitaId == partitaId) return prenotazione;
    }
    return null;
  }

  @override
  /// Restituisce le Prenotazioni associate al Campo indicato.
  Future<List<Prenotazione>> findByCampo(String campoId) async {
    return _prenotazioni.values
        .where((prenotazione) => prenotazione.campoId == campoId)
        .toList();
  }

  @override
  /// Crea una Prenotazione assegnando un UUID fittizio e validandone i vincoli.
  Future<Prenotazione> createPrenotazione(Prenotazione prenotazione) async {
    final id = prenotazione.id.isEmpty ? _generateId() : prenotazione.id;
    final created = Prenotazione(
      id: id,
      partitaId: prenotazione.partitaId,
      campoId: prenotazione.campoId,
      intervallo: prenotazione.intervallo,
      statoBlocco: prenotazione.statoBlocco,
      scadenzaBlocco: prenotazione.scadenzaBlocco,
      costoConcordato: prenotazione.costoConcordato,
      quotaIndividuale: prenotazione.quotaIndividuale,
      commissione: prenotazione.commissione,
      nettoGestore: prenotazione.nettoGestore,
    );
    _validate(created);
    _prenotazioni[id] = created;
    return created;
  }

  @override
  /// Aggiorna i dati della Prenotazione dopo aver verificato esistenza e vincoli.
  Future<Prenotazione> updatePrenotazione(Prenotazione prenotazione) async {
    _requirePrenotazione(prenotazione.id);
    _validate(prenotazione);
    _prenotazioni[prenotazione.id] = prenotazione;
    return prenotazione;
  }

  @override
  /// Aggiorna lo stato del blocco conservando gli altri dati della Prenotazione.
  Future<Prenotazione> updateStatoBlocco(
    String id,
    String statoBlocco,
    DateTime? scadenzaBlocco,
  ) async {
    _requirePrenotazione(id);
    final old = _prenotazioni[id]!;
    final updated = Prenotazione(
      id: old.id,
      partitaId: old.partitaId,
      campoId: old.campoId,
      intervallo: old.intervallo,
      statoBlocco: statoBlocco,
      scadenzaBlocco: scadenzaBlocco,
      costoConcordato: old.costoConcordato,
      quotaIndividuale: old.quotaIndividuale,
      commissione: old.commissione,
      nettoGestore: old.nettoGestore,
    );
    _validate(updated);
    _prenotazioni[id] = updated;
    return updated;
  }

  @override
  /// Elimina la Prenotazione dalla memoria dopo averne verificato l'esistenza.
  Future<void> deletePrenotazione(String id) async {
    _requirePrenotazione(id);
    _prenotazioni.remove(id);
  }
}
