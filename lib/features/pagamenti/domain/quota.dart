// Entity Quota del class diagram (docs/modelli/class.puml).
//
// Rappresenta la quota individuale dovuta per una partecipazione (una sola
// per partecipazione, regola 8): importo, stato del versamento e termine.
// Creazione, importo e termine li decide GestioneTransazioniControl (D25).

/// Valori ammessi per `Quota.statoVersamento` (CHECK
/// `quota_stato_versamento_check`, D25).
///
/// Solo i valori: i passaggi tra di essi li fa GestioneTransazioniControl.
abstract final class StatoVersamento {
  /// Quota creata e non ancora versata.
  static const daVersare = 'da_versare';

  /// Quota versata.
  static const versata = 'versata';

  /// Quota rimborsata (RF_PAG_3).
  static const rimborsata = 'rimborsata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {daVersare, versata, rimborsata};
}

/// Quota di Kickly, letta dalla tabella `quota`.
///
/// `id` e `partecipazioneId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della Migration C.
class Quota {
  /// Chiave della quota (colonna `id`).
  final String id;

  /// Partecipazione a cui si riferisce la quota (associazione 15).
  final String partecipazioneId;

  /// Importo da versare.
  final double importo;

  /// Stato del versamento, uno dei valori di [StatoVersamento].
  final String statoVersamento;

  /// Termine entro cui versare la quota.
  final DateTime termineVersamento;

  /// Crea una Quota con tutti gli attributi del class diagram.
  const Quota({
    required this.id,
    required this.partecipazioneId,
    required this.importo,
    required this.statoVersamento,
    required this.termineVersamento,
  });

  /// Crea una Quota da una riga di `quota` come la restituisce Supabase.
  /// L'importo puo' arrivare come intero (es. 6) o con decimali (es. 6.5):
  /// si legge come num e si converte in double. Non valida i valori: li
  /// controllano le CHECK del database.
  factory Quota.fromJson(Map<String, dynamic> json) {
    return Quota(
      id: json['id'] as String,
      partecipazioneId: json['partecipazione_id'] as String,
      importo: (json['importo'] as num).toDouble(),
      statoVersamento: json['stato_versamento'] as String,
      termineVersamento: DateTime.parse(json['termine_versamento'] as String),
    );
  }

  /// Converte la Quota nella mappa delle colonne di `quota`, con il termine
  /// in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partecipazione_id': partecipazioneId,
      'importo': importo,
      'stato_versamento': statoVersamento,
      'termine_versamento': termineVersamento.toUtc().toIso8601String(),
    };
  }
}
