// Entity Partecipazione del class diagram (docs/modelli/class.puml).
//
// Registra la risposta di un Giocatore a una partita (una sola per coppia
// giocatore-partita, regola 8 e DG3) e le sue statistiche, inserite
// dall'Organizzatore a partita Conclusa (D2).

/// Valori ammessi per `Partecipazione.rispostaStato` (CHECK
/// `partecipazione_risposta_stato_check`, D24).
///
/// Solo i valori: i passaggi tra di essi li fa GestionePartecipazioneControl.
abstract final class RispostaStato {
  /// Presenza confermata.
  static const confermata = 'confermata';

  /// Presenza ritirata (ritiro presenza dello statechart della partita).
  static const ritirata = 'ritirata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {confermata, ritirata};
}

/// Partecipazione di Kickly, letta dalla tabella `partecipazione`.
///
/// `id`, `giocatoreId` e `partitaId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della migration B.
class Partecipazione {
  /// Chiave della partecipazione (colonna `id`).
  final String id;

  /// Giocatore che ha risposto (associazione 12).
  final String giocatoreId;

  /// Partita a cui si riferisce la risposta (associazione 13).
  final String partitaId;

  /// Risposta del giocatore, uno dei valori di [RispostaStato].
  final String rispostaStato;

  /// Data e ora della risposta.
  final DateTime dataRisposta;

  /// Gol segnati nella partita; 0 se non inseriti.
  final int golPartita;

  /// Assist forniti nella partita; 0 se non inseriti.
  final int assistPartita;

  /// Crea una Partecipazione con tutti gli attributi del class diagram.
  /// Gol e assist sono obbligatori: il valore 0 di default e' solo nel
  /// database, l'entity non contiene logica.
  const Partecipazione({
    required this.id,
    required this.giocatoreId,
    required this.partitaId,
    required this.rispostaStato,
    required this.dataRisposta,
    required this.golPartita,
    required this.assistPartita,
  });

  /// Crea una Partecipazione da una riga di `partecipazione` come la
  /// restituisce Supabase. Non valida i valori: li controllano le CHECK del
  /// database.
  factory Partecipazione.fromJson(Map<String, dynamic> json) {
    return Partecipazione(
      id: json['id'] as String,
      giocatoreId: json['giocatore_id'] as String,
      partitaId: json['partita_id'] as String,
      rispostaStato: json['risposta_stato'] as String,
      dataRisposta: DateTime.parse(json['data_risposta'] as String),
      golPartita: json['gol_partita'] as int,
      assistPartita: json['assist_partita'] as int,
    );
  }

  /// Converte la Partecipazione nella mappa delle colonne di
  /// `partecipazione`, con la data della risposta in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giocatore_id': giocatoreId,
      'partita_id': partitaId,
      'risposta_stato': rispostaStato,
      'data_risposta': dataRisposta.toUtc().toIso8601String(),
      'gol_partita': golPartita,
      'assist_partita': assistPartita,
    };
  }
}
