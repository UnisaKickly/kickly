import 'package:flutter/foundation.dart';
import 'package:kickly/core/errors/app_exception.dart';

import '../domain/quota.dart';
import '../domain/quota_repository.dart';

/// Implementazione in memoria di QuotaRepository per test dei Control.
///
/// Mantiene quote e associazioni partecipazione-partita senza SDK esterni,
/// cosi' i filtri D25 e D26 sono verificabili nei test.
class InMemoryQuotaRepository implements QuotaRepository {
  /// Crea il repository con quote e associazioni opzionali.
  InMemoryQuotaRepository({
    Iterable<Quota>? quote,
    Map<String, String>? partecipazionePartite,
  }) {
    if (quote != null) {
      for (final quota in quote) {
        _quote[quota.id] = quota;
      }
    }
    if (partecipazionePartite != null) {
      _partecipazionePartite.addAll(partecipazionePartite);
    }
  }

  final Map<String, Quota> _quote = {};
  final Map<String, String> _partecipazionePartite = {};
  int _nextId = 1;

  /// Genera un UUID fittizio stabile per una quota creata nei test.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Verifica che la quota esista prima di modificarla o eliminarla.
  void _requireQuota(String id) {
    if (!_quote.containsKey(id)) {
      throw AppException.database(
        message: 'La quota richiesta non esiste.',
        code: '23503',
      );
    }
  }

  /// Verifica che lo stato appartenga ai valori ammessi dal CHECK.
  void _requireStatoVersamento(String statoVersamento) {
    if (!StatoVersamento.valori.contains(statoVersamento)) {
      throw AppException.database(
        message: "Lo stato di versamento della quota non e' valido.",
        code: '23514',
      );
    }
  }

  /// Associa una partecipazione alla partita nei soli test del repository.
  @visibleForTesting
  void collegaPartecipazioneAPartita(
    String partecipazioneId,
    String partitaId,
  ) {
    _partecipazionePartite[partecipazioneId] = partitaId;
  }

  /// Aggiunge o sostituisce una quota nei soli test del repository.
  @visibleForTesting
  void aggiungiQuota(Quota quota) {
    _quote[quota.id] = quota;
  }

  @override
  /// Recupera la quota dalla memoria tramite la sua chiave.
  Future<Quota?> findById(String id) async => _quote[id];

  @override
  /// Legge la quota tramite la chiave, come `findById`.
  Future<Quota?> leggiQuota(String quotaId) => findById(quotaId);

  @override
  /// Recupera l'unica quota associata alla partecipazione indicata.
  Future<Quota?> findByPartecipazione(String partecipazioneId) async {
    for (final quota in _quote.values) {
      if (quota.partecipazioneId == partecipazioneId) return quota;
    }
    return null;
  }

  @override
  /// Restituisce le quote da versare della partita indicata.
  Future<List<Quota>> findDaVersareByPartita(String partitaId) async {
    return _quote.values
        .where(
          (quota) =>
              quota.statoVersamento == StatoVersamento.daVersare &&
              _partecipazionePartite[quota.partecipazioneId] == partitaId,
        )
        .toList();
  }

  @override
  /// Conta le quote da versare della partita indicata.
  Future<int> countDaVersareByPartita(String partitaId) async {
    final quote = await findDaVersareByPartita(partitaId);
    return quote.length;
  }

  @override
  /// Crea una quota assegnando un UUID fittizio se manca l'id.
  Future<Quota> createQuota(Quota quota) async {
    _requireStatoVersamento(quota.statoVersamento);
    if (quota.id.isNotEmpty && _quote.containsKey(quota.id)) {
      throw AppException.database(
        message: "Esiste gia' una quota con questo identificativo.",
        code: '23505',
      );
    }
    if (_quote.values.any(
      (existing) => existing.partecipazioneId == quota.partecipazioneId,
    )) {
      throw AppException.database(
        message: "Esiste gia' una quota per questa partecipazione.",
        code: '23505',
      );
    }
    final id = quota.id.isEmpty ? _generateId() : quota.id;
    final created = Quota(
      id: id,
      partecipazioneId: quota.partecipazioneId,
      importo: quota.importo,
      statoVersamento: quota.statoVersamento,
      termineVersamento: quota.termineVersamento,
    );
    _quote[id] = created;
    return created;
  }

  @override
  /// Aggiorna lo stato di versamento della quota esistente.
  Future<void> updateStatoVersamento(String id, String statoVersamento) async {
    _requireStatoVersamento(statoVersamento);
    _requireQuota(id);
    final quota = _quote[id]!;
    _quote[id] = Quota(
      id: quota.id,
      partecipazioneId: quota.partecipazioneId,
      importo: quota.importo,
      statoVersamento: statoVersamento,
      termineVersamento: quota.termineVersamento,
    );
  }

  @override
  /// Registra il versamento impostando lo stato a `versata`.
  Future<void> registraVersamento(String quotaId) {
    return updateStatoVersamento(quotaId, StatoVersamento.versata);
  }

  @override
  /// Elimina la quota solo se e' ancora nello stato da_versare.
  Future<void> deleteDaVersare(String id) async {
    _requireQuota(id);
    if (_quote[id]!.statoVersamento != StatoVersamento.daVersare) {
      throw AppException.database(
        message: "Una quota versata non puo' essere eliminata.",
        code: '23514',
      );
    }
    _quote.remove(id);
  }

  @override
  /// Verifica che tutte le quote della partita siano versate.
  Future<bool> tutteLeQuoteVersate(String partitaId) async {
    final quotePartita = _quote.values.where(
      (quota) => _partecipazionePartite[quota.partecipazioneId] == partitaId,
    );
    return !quotePartita.any(
      (quota) => quota.statoVersamento == StatoVersamento.daVersare,
    );
  }
}
