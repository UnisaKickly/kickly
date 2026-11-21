// Entity Prenotazione del class diagram (docs/modelli/class.puml).
//
// Descrive lo slot di un campo prenotato per una partita (una sola
// prenotazione per partita, regola 8), lo stato del blocco e la divisione
// del costo concordato. Il vincolo sugli slot sovrapposti e' nel database
// (D24), il rilascio del blocco scaduto in PrenotazioneControl.

/// Valori ammessi per `Prenotazione.statoBlocco` (CHECK
/// `prenotazione_stato_blocco_check`, D24).
///
/// Solo i valori: i passaggi tra di essi li fa PrenotazioneControl.
abstract final class StatoBlocco {
  /// Slot bloccato temporaneamente, fino a `scadenzaBlocco`.
  static const bloccato = 'bloccato';

  /// Slot confermato.
  static const confermato = 'confermato';

  /// Slot liberato: non occupa piu' il campo.
  static const liberato = 'liberato';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {bloccato, confermato, liberato};
}

/// Prenotazione di Kickly, letta dalla tabella `prenotazione`.
///
/// `id`, `partitaId` e `campoId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della migration B.
class Prenotazione {
  /// Chiave della prenotazione (colonna `id`).
  final String id;

  /// Partita a cui appartiene la prenotazione (associazione 5).
  final String partitaId;

  /// Campo prenotato (associazione 4).
  final String campoId;

  /// Slot nel formato 'AAAA-MM-GGTHH:MM/AAAA-MM-GGTHH:MM' (regola 4).
  final String intervallo;

  /// Stato del blocco, uno dei valori di [StatoBlocco].
  final String statoBlocco;

  /// Scadenza del blocco temporaneo; sempre presente quando lo slot e'
  /// bloccato (vincolo nel database), altrimenti puo' essere null.
  final DateTime? scadenzaBlocco;

  /// Costo concordato per lo slot.
  final double costoConcordato;

  /// Quota che versa ogni partecipante.
  final double quotaIndividuale;

  /// Commissione della piattaforma.
  final double commissione;

  /// Importo che resta al Gestore del Campo.
  final double nettoGestore;

  /// Crea una Prenotazione con tutti gli attributi del class diagram.
  const Prenotazione({
    required this.id,
    required this.partitaId,
    required this.campoId,
    required this.intervallo,
    required this.statoBlocco,
    this.scadenzaBlocco,
    required this.costoConcordato,
    required this.quotaIndividuale,
    required this.commissione,
    required this.nettoGestore,
  });

  /// Crea una Prenotazione da una riga di `prenotazione` come la restituisce
  /// Supabase. Gli importi possono arrivare come interi (es. 60) o con
  /// decimali (es. 6.5): si leggono come num e si convertono in double.
  /// Non valida i valori: li controllano le CHECK del database.
  factory Prenotazione.fromJson(Map<String, dynamic> json) {
    final scadenza = json['scadenza_blocco'] as String?;
    return Prenotazione(
      id: json['id'] as String,
      partitaId: json['partita_id'] as String,
      campoId: json['campo_id'] as String,
      intervallo: json['intervallo'] as String,
      statoBlocco: json['stato_blocco'] as String,
      scadenzaBlocco: scadenza == null ? null : DateTime.parse(scadenza),
      costoConcordato: (json['costo_concordato'] as num).toDouble(),
      quotaIndividuale: (json['quota_individuale'] as num).toDouble(),
      commissione: (json['commissione'] as num).toDouble(),
      nettoGestore: (json['netto_gestore'] as num).toDouble(),
    );
  }

  /// Converte la Prenotazione nella mappa delle colonne di `prenotazione`,
  /// con la scadenza in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partita_id': partitaId,
      'campo_id': campoId,
      'intervallo': intervallo,
      'stato_blocco': statoBlocco,
      'scadenza_blocco': scadenzaBlocco?.toUtc().toIso8601String(),
      'costo_concordato': costoConcordato,
      'quota_individuale': quotaIndividuale,
      'commissione': commissione,
      'netto_gestore': nettoGestore,
    };
  }
}
