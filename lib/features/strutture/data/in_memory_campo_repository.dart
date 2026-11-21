import 'package:kickly/core/errors/app_exception.dart';

import '../domain/campo.dart';
import '../domain/campo_repository.dart';

/// Implementazione in memoria di CampoRepository.
///
/// Permette test unitari deterministici senza SDK esterni e conserva UUID
/// fittizi sequenziali coerenti con il comportamento Supabase.
class InMemoryCampoRepository implements CampoRepository {
  /// Crea un repository vuoto pronto per i test.
  InMemoryCampoRepository();

  final Map<String, Campo> _campi = {};
  int _nextId = 1;

  /// Genera un UUID fittizio stabile senza dipendenze esterne.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Verifica che il campo esista prima di aggiornarlo.
  void _requireCampo(String id) {
    if (!_campi.containsKey(id)) {
      throw AppException.database(
        message: 'Il campo richiesto non esiste.',
        code: '23503',
      );
    }
  }

  @override
  /// Recupera il Campo dalla memoria tramite la sua chiave.
  Future<Campo?> findById(String id) async => _campi[id];

  @override
  /// Restituisce i campi appartenenti al GestoreCampo indicato.
  Future<List<Campo>> findByGestoreCampo(String gestoreCampoId) async {
    return _campi.values
        .where((campo) => campo.gestoreCampoId == gestoreCampoId)
        .toList();
  }

  @override
  /// Crea un Campo assegnando un UUID fittizio quando manca l'identificativo.
  Future<Campo> createCampo(Campo campo) async {
    final id = campo.id.isEmpty ? _generateId() : campo.id;
    final created = Campo(
      id: id,
      gestoreCampoId: campo.gestoreCampoId,
      nome: campo.nome,
      ubicazione: campo.ubicazione,
      tariffaOraria: campo.tariffaOraria,
      orariDisponibilita: campo.orariDisponibilita,
    );
    _campi[id] = created;
    return created;
  }

  @override
  /// Sostituisce i dati del Campo esistente nella memoria del test.
  Future<Campo> updateCampo(Campo campo) async {
    _requireCampo(campo.id);
    _campi[campo.id] = campo;
    return campo;
  }

  @override
  /// Elimina il Campo dalla memoria dopo averne verificato l'esistenza.
  Future<void> deleteCampo(String id) async {
    _requireCampo(id);
    _campi.remove(id);
  }

  @override
  /// Restituisce gli orari di disponibilita' memorizzati per il Campo.
  Future<String?> getDisponibilita(String campoId) async =>
      _campi[campoId]?.orariDisponibilita;

  @override
  /// Restituisce la tariffa oraria memorizzata per il Campo.
  Future<double?> getTariffa(String campoId) async =>
      _campi[campoId]?.tariffaOraria;
}
