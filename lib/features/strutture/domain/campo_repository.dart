import 'campo.dart';

/// Contratto di persistenza per i campi sportivi.
///
/// Mantiene separata dal dominio la tecnologia usata per leggere il database
/// e permette ai Control del sottosistema Strutture di restare portabili.
abstract interface class CampoRepository {
  /// Cerca un campo tramite la sua chiave.
  Future<Campo?> findById(String id);

  /// Restituisce i campi gestiti da un determinato GestoreCampo.
  Future<List<Campo>> findByGestoreCampo(String gestoreCampoId);

  /// Crea un campo: l'identificativo viene assegnato dal database.
  Future<Campo> createCampo(Campo campo);

  /// Aggiorna i dati persistiti del campo.
  Future<Campo> updateCampo(Campo campo);

  /// Elimina un campo tramite la sua chiave.
  Future<void> deleteCampo(String id);

  /// Restituisce gli orari di disponibilita' del campo.
  Future<String?> getDisponibilita(String campoId);

  /// Restituisce la tariffa oraria del campo.
  Future<double?> getTariffa(String campoId);
}
