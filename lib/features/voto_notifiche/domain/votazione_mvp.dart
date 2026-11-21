// Entity VotazioneMVP del class diagram (docs/modelli/class.puml).
//
// Raccoglie lo stato e la scadenza della votazione MVP di una partita (una
// sola per partita, regola 8) e l'eventuale vincitore. L'attributo
// preferenzeVotanteVotato del class diagram non e' nell'entity: le
// preferenze sono la tabella `preferenza_voto_mvp` (regola 6) e le gestisce
// VotazioneMVPRepository, come i membri di Lega.

/// Valori ammessi per `VotazioneMVP.statoVotazione` (CHECK
/// `votazione_mvp_stato_votazione_check`, D27).
///
/// Solo i valori: apertura e chiusura le fa VotoMVPControl.
abstract final class StatoVotazione {
  /// Votazione aperta quando la partita passa a Conclusa (D1).
  static const aperta = 'aperta';

  /// Votazione chiusa alla scadenza o a voti completati, con il vincitore.
  static const chiusa = 'chiusa';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {aperta, chiusa};
}

/// Votazione MVP di Kickly, letta dalla tabella `votazione_mvp`.
///
/// `id`, `partitaId` e `vincitoreId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della Migration C.
class VotazioneMVP {
  /// Chiave della votazione (colonna `id`).
  final String id;

  /// Partita a cui si riferisce la votazione (associazione 14).
  final String partitaId;

  /// Stato della votazione, uno dei valori di [StatoVotazione].
  final String statoVotazione;

  /// Scadenza della votazione.
  final DateTime scadenza;

  /// Giocatore vincitore; null finche' la votazione non ha un vincitore.
  final String? vincitoreId;

  /// Crea una VotazioneMVP con gli attributi del class diagram, senza le
  /// preferenze (le gestisce il repository).
  const VotazioneMVP({
    required this.id,
    required this.partitaId,
    required this.statoVotazione,
    required this.scadenza,
    this.vincitoreId,
  });

  /// Crea una VotazioneMVP da una riga di `votazione_mvp` come la
  /// restituisce Supabase. Non valida i valori: li controllano le CHECK del
  /// database.
  factory VotazioneMVP.fromJson(Map<String, dynamic> json) {
    return VotazioneMVP(
      id: json['id'] as String,
      partitaId: json['partita_id'] as String,
      statoVotazione: json['stato_votazione'] as String,
      scadenza: DateTime.parse(json['scadenza'] as String),
      vincitoreId: json['vincitore_id'] as String?,
    );
  }

  /// Converte la VotazioneMVP nella mappa delle colonne di `votazione_mvp`,
  /// con la scadenza in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partita_id': partitaId,
      'stato_votazione': statoVotazione,
      'scadenza': scadenza.toUtc().toIso8601String(),
      'vincitore_id': vincitoreId,
    };
  }
}
