import 'package:kickly/core/errors/app_exception.dart';

import '../domain/gestione_adesione_control.dart';
import '../domain/lega.dart';
import '../domain/lega_repository.dart';

/// Implementazione in memoria di LegaRepository per test e sviluppo locale.
class InMemoryLegaRepository implements LegaRepository {
  /// Crea un repository vuoto con ID deterministici e orologio configurabile.
  ///
  /// [orologio] permette di verificare la scadenza degli inviti nei test; se
  /// omesso usa l'orologio di sistema.
  InMemoryLegaRepository({DateTime Function()? orologio})
    : _orologio = orologio ?? DateTime.now;

  final Map<String, Lega> _leghe = {};
  final Map<String, Set<String>> _membri = {};
  final Map<String, Set<String>> _amministratori = {};
  final DateTime Function() _orologio;
  int _nextId = 1;

  /// Caratteri ammessi dal formato D29, senza lettere o cifre ambigue.
  static const _caratteriCodiceInvito = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Genera un UUID fittizio stabile senza dipendenze esterne.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Normalizza un nome come l'indice univoco della migration A.
  String _normalizeName(String name) => name.trim().toLowerCase();

  /// Crea l'errore applicativo per l'ultimo amministratore.
  AppException _lastAdminError() {
    return AppException.database(
      message: 'Nomina un altro amministratore prima di uscire.',
      code: '23514',
    );
  }

  /// Crea l'errore applicativo per un riferimento mancante.
  AppException _missingMemberError() {
    return AppException.database(
      message: 'Il giocatore deve essere membro della lega.',
      code: '23503',
    );
  }

  /// Verifica che la lega esista.
  void _requireLega(String legaId) {
    if (!_leghe.containsKey(legaId)) {
      throw _missingMemberError();
    }
  }

  @override
  Future<Lega> createLega(Lega lega, String adminGiocatoreId) async {
    final id = lega.id.isEmpty ? _generateId() : lega.id;
    final created = Lega(
      id: id,
      nome: lega.nome,
      tipologiaMatch: lega.tipologiaMatch,
      privacy: lega.privacy,
      codiceInvito: lega.codiceInvito,
      scadenzaCodiceInvito: lega.scadenzaCodiceInvito,
    );
    if (await existsByNome(created.nome)) {
      throw AppException.database(
        message: 'Esiste già un elemento con questi dati.',
        code: '23505',
      );
    }
    _leghe[id] = created;
    _membri[id] = {adminGiocatoreId};
    _amministratori[id] = {adminGiocatoreId};
    return created;
  }

  @override
  Future<Lega> updateLega(Lega lega) async {
    _requireLega(lega.id);
    _leghe[lega.id] = lega;
    return lega;
  }

  @override
  Future<Lega?> findById(String id) async => _leghe[id];

  @override
  Future<Lega?> findByCodiceInvito(String codiceInvito) async {
    for (final lega in _leghe.values) {
      if (lega.codiceInvito == codiceInvito) {
        return lega;
      }
    }
    return null;
  }

  /// Valida il codice e aggiunge il Giocatore alla lega in memoria.
  ///
  /// Mantiene la stessa normalizzazione, scadenza e protezione dai duplicati
  /// della RPC, usando [giocatoreId] come identità locale del chiamante.
  @override
  Future<Lega> uniscitiConCodice(
    String codiceInvito,
    String giocatoreId,
  ) async {
    final codice = codiceInvito.trim().toUpperCase();
    if (codice.length != 8 ||
        codice.runes.any(
          (int carattere) =>
              !_caratteriCodiceInvito.contains(String.fromCharCode(carattere)),
        )) {
      throw CodiceInvitoNonValidoException();
    }

    final Lega? lega = await findByCodiceInvito(codice);
    if (lega == null) {
      throw CodiceInvitoNonValidoException();
    }
    final DateTime? scadenza = lega.scadenzaCodiceInvito;
    if (scadenza == null || !_orologio().isBefore(scadenza)) {
      throw CodiceInvitoScadutoException();
    }

    final membri = _membri[lega.id]!;
    if (membri.contains(giocatoreId)) {
      throw GiocatoreGiaMembroException();
    }
    membri.add(giocatoreId);
    return lega;
  }

  @override
  Future<bool> existsByNome(String nome) async {
    final normalized = _normalizeName(nome);
    return _leghe.values.any((lega) => _normalizeName(lega.nome) == normalized);
  }

  @override
  Future<List<Lega>> findByGiocatore(String giocatoreId) async {
    return _leghe.values
        .where((lega) => _membri[lega.id]?.contains(giocatoreId) ?? false)
        .toList();
  }

  @override
  Future<List<String>> findMembri(String legaId) async {
    return List<String>.of(_membri[legaId] ?? const <String>{});
  }

  @override
  Future<List<Lega>> findPubbliche() async {
    return _leghe.values
        .where((lega) => lega.privacy == PrivacyLega.pubblica)
        .toList();
  }

  @override
  Future<void> aggiungiMembro(
    String legaId,
    String giocatoreId, {
    bool isAdmin = false,
  }) async {
    _requireLega(legaId);
    final membri = _membri[legaId]!;
    if (membri.contains(giocatoreId) && !isAdmin) {
      throw AppException.database(
        message: 'Esiste già un elemento con questi dati.',
        code: '23505',
      );
    }
    membri.add(giocatoreId);
    if (isAdmin) {
      _amministratori[legaId]!.add(giocatoreId);
    }
  }

  @override
  Future<void> rimuoviMembro(String legaId, String giocatoreId) async {
    _requireLega(legaId);
    final amministratori = _amministratori[legaId]!;
    if (amministratori.contains(giocatoreId) && amministratori.length <= 1) {
      throw _lastAdminError();
    }
    amministratori.remove(giocatoreId);
    _membri[legaId]!.remove(giocatoreId);
  }

  @override
  Future<void> promuoviAdAdmin(String legaId, String giocatoreId) async {
    _requireLega(legaId);
    if (!(_membri[legaId]?.contains(giocatoreId) ?? false)) {
      throw _missingMemberError();
    }
    _amministratori[legaId]!.add(giocatoreId);
  }

  @override
  Future<bool> isAmministratore(String legaId, String giocatoreId) async {
    return _amministratori[legaId]?.contains(giocatoreId) ?? false;
  }
}
