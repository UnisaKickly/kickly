import 'package:kickly/core/errors/app_exception.dart';

import '../domain/votazione_mvp.dart';
import '../domain/votazione_mvp_repository.dart';

/// Implementazione in memoria di VotazioneMVPRepository per test e Control.
///
/// Mantiene votazioni e preferenze MVP senza SDK esterni, applicando unicita'
/// del voto per votazione/votante e vietando l'autovoto.
class InMemoryVotazioneMVPRepository implements VotazioneMVPRepository {
  /// Crea il repository con le votazioni iniziali opzionali.
  InMemoryVotazioneMVPRepository({Iterable<VotazioneMVP>? votazioni}) {
    if (votazioni != null) {
      for (final votazione in votazioni) {
        _requireStatoVotazione(votazione.statoVotazione);
        _votazioni[votazione.id] = votazione;
      }
    }
  }

  final Map<String, VotazioneMVP> _votazioni = {};
  final Map<String, Map<String, String>> _preferenze = {};

  /// Verifica che la votazione esista prima di modificarla.
  void _requireVotazione(String votazioneId) {
    if (!_votazioni.containsKey(votazioneId)) {
      throw AppException.database(
        message: 'La votazione richiesta non esiste.',
        code: '23503',
      );
    }
  }

  /// Verifica che lo stato appartenga ai valori ammessi dal CHECK.
  void _requireStatoVotazione(String statoVotazione) {
    if (!StatoVotazione.valori.contains(statoVotazione)) {
      throw AppException.database(
        message: "Lo stato della votazione MVP non e' valido.",
        code: '23514',
      );
    }
  }

  @override
  /// Recupera la votazione dalla memoria tramite la sua chiave.
  Future<VotazioneMVP?> findById(String id) async => _votazioni[id];

  @override
  /// Recupera la votazione associata alla partita indicata.
  Future<VotazioneMVP?> findByPartita(String partitaId) async {
    for (final votazione in _votazioni.values) {
      if (votazione.partitaId == partitaId) return votazione;
    }
    return null;
  }

  @override
  /// Recupera il giocatore votato dal votante nella votazione indicata.
  Future<String?> findPreferenzaVotato(
    String votazioneId,
    String votanteId,
  ) async {
    return _preferenze[votazioneId]?[votanteId];
  }

  @override
  /// Registra una sola preferenza per coppia votazione/votante.
  Future<void> registraPreferenza(
    String votazioneId,
    String votanteId,
    String votatoId,
  ) async {
    _requireVotazione(votazioneId);
    if (votanteId == votatoId) {
      throw AppException.database(
        message: "Un giocatore non puo' auto-votarsi.",
        code: '23514',
      );
    }
    final preferenzeVotazione = _preferenze.putIfAbsent(
      votazioneId,
      () => <String, String>{},
    );
    if (preferenzeVotazione.containsKey(votanteId)) {
      throw AppException.database(
        message: "Esiste gia' una preferenza per questo votante.",
        code: '23505',
      );
    }
    preferenzeVotazione[votanteId] = votatoId;
  }

  @override
  /// Aggiorna il vincitore della votazione esistente.
  Future<void> updateVincitore(String votazioneId, String? vincitoreId) async {
    _requireVotazione(votazioneId);
    final votazione = _votazioni[votazioneId]!;
    _votazioni[votazioneId] = VotazioneMVP(
      id: votazione.id,
      partitaId: votazione.partitaId,
      statoVotazione: votazione.statoVotazione,
      scadenza: votazione.scadenza,
      vincitoreId: vincitoreId,
    );
  }

  @override
  /// Aggiorna lo stato della votazione esistente.
  Future<void> updateStato(String votazioneId, String statoVotazione) async {
    _requireStatoVotazione(statoVotazione);
    _requireVotazione(votazioneId);
    final votazione = _votazioni[votazioneId]!;
    _votazioni[votazioneId] = VotazioneMVP(
      id: votazione.id,
      partitaId: votazione.partitaId,
      statoVotazione: statoVotazione,
      scadenza: votazione.scadenza,
      vincitoreId: votazione.vincitoreId,
    );
  }
}
