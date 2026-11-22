import 'package:kickly/core/errors/app_exception.dart';

import '../domain/notifica.dart';
import '../domain/notifica_repository.dart';

/// Implementazione in memoria di NotificaRepository per test e UI locale.
class InMemoryNotificaRepository implements NotificaRepository {
  /// Crea il repository con le notifiche iniziali opzionali.
  InMemoryNotificaRepository({Iterable<Notifica>? notifiche}) {
    if (notifiche != null) {
      for (final notifica in notifiche) {
        _notifiche[notifica.id] = notifica;
      }
    }
  }

  final Map<String, Notifica> _notifiche = {};

  /// Verifica che la notifica esista prima di aggiornarla.
  void _requireNotifica(String id) {
    if (!_notifiche.containsKey(id)) {
      throw AppException.database(
        message: 'La notifica richiesta non esiste.',
        code: '23503',
      );
    }
  }

  @override
  /// Recupera la notifica dalla memoria tramite la sua chiave.
  Future<Notifica?> findById(String id) async => _notifiche[id];

  @override
  /// Restituisce tutte le notifiche dell'account indicato.
  Future<List<Notifica>> findByAccount(String accountId) async {
    return _notifiche.values
        .where((notifica) => notifica.accountId == accountId)
        .toList();
  }

  @override
  /// Restituisce le notifiche non lette dell'account indicato.
  Future<List<Notifica>> findNonLetteByAccount(String accountId) async {
    return _notifiche.values
        .where(
          (notifica) =>
              notifica.accountId == accountId && notifica.statoLettura == false,
        )
        .toList();
  }

  @override
  /// Aggiorna lo stato di lettura della notifica esistente.
  Future<void> updateStatoLettura(String id, bool statoLettura) async {
    _requireNotifica(id);
    final notifica = _notifiche[id]!;
    _notifiche[id] = Notifica(
      id: notifica.id,
      accountId: notifica.accountId,
      tipo: notifica.tipo,
      messaggio: notifica.messaggio,
      statoLettura: statoLettura,
      timestamp: notifica.timestamp,
    );
  }
}
