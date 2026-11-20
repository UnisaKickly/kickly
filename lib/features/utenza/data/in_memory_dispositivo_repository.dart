import 'package:kickly/core/errors/app_exception.dart';

import '../domain/dispositivo_registrato.dart';
import '../domain/dispositivo_repository.dart';

/// Implementazione in memoria di DispositivoRepository per test e sviluppo.
class InMemoryDispositivoRepository implements DispositivoRepository {
  /// Crea un repository vuoto con ID deterministici.
  InMemoryDispositivoRepository();

  final Map<String, DispositivoRegistrato> _dispositivi = {};
  int _nextId = 1;

  /// Genera un UUID fittizio stabile senza dipendenze esterne.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Verifica il vincolo UNIQUE su account e identificativo.
  void _ensureUnique(String accountId, String identificativo) {
    final duplicate = _dispositivi.values.any(
      (device) =>
          device.accountId == accountId &&
          device.identificativo == identificativo,
    );
    if (duplicate) {
      throw AppException.database(
        message: 'Esiste già un elemento con questi dati.',
        code: '23505',
      );
    }
  }

  @override
  Future<DispositivoRegistrato?> findByAccountAndIdentificativo(
    String accountId,
    String identificativo,
  ) async {
    for (final dispositivo in _dispositivi.values) {
      if (dispositivo.accountId == accountId &&
          dispositivo.identificativo == identificativo) {
        return dispositivo;
      }
    }
    return null;
  }

  @override
  Future<List<DispositivoRegistrato>> findByAccount(String accountId) async {
    return _dispositivi.values
        .where((dispositivo) => dispositivo.accountId == accountId)
        .toList();
  }

  @override
  Future<DispositivoRegistrato> registerDispositivo(
    String accountId,
    DispositivoRegistrato dispositivo,
  ) async {
    _ensureUnique(accountId, dispositivo.identificativo);
    final id = dispositivo.id.isEmpty ? _generateId() : dispositivo.id;
    final saved = DispositivoRegistrato(
      id: id,
      accountId: accountId,
      identificativo: dispositivo.identificativo,
      primoAccesso: dispositivo.primoAccesso,
      ultimoAccesso: dispositivo.ultimoAccesso,
    );
    _dispositivi[id] = saved;
    return saved;
  }

  @override
  Future<void> updateUltimoAccesso(String id, DateTime ultimoAccesso) async {
    final dispositivo = _dispositivi[id];
    if (dispositivo == null) {
      return;
    }
    _dispositivi[id] = DispositivoRegistrato(
      id: dispositivo.id,
      accountId: dispositivo.accountId,
      identificativo: dispositivo.identificativo,
      primoAccesso: dispositivo.primoAccesso,
      ultimoAccesso: ultimoAccesso,
    );
  }
}
