// Entity Partita del class diagram (docs/modelli/class.puml).
//
// Raccoglie i dati di una partita: organizzatore, lega facoltativa, data,
// tipologia, privacy, numero di partecipanti e stato dello statechart
// (docs/modelli/statechart_partita.puml). Prenotazione e partecipazioni sono
// entity separate, lette dai rispettivi repository.
//
// Le classi di costanti stanno qui e non si importano da leghe/domain:
// component.puml ammette solo la dipendenza Leghe -> Partite.

/// Valori ammessi per `Partita.tipologia`.
///
/// Costanti String e non un enum (class_diagram_sdd.md §3, regola 1), con i
/// valori della CHECK `partita_tipologia_check`, gli stessi di
/// `lega.tipologia_match`. I nomi sono in lettere perche' in Dart un
/// identificatore non puo' iniziare con una cifra. La conversione verso il
/// formato "5vs5" dei casi d'uso non e' compito dell'entity.
abstract final class TipologiaPartita {
  /// Partita 5 contro 5.
  static const cinqueVsCinque = '5v5';

  /// Partita 6 contro 6.
  static const seiVsSei = '6v6';

  /// Partita 7 contro 7.
  static const setteVsSette = '7v7';

  /// Partita 8 contro 8.
  static const ottoVsOtto = '8v8';

  /// Partita 9 contro 9.
  static const noveVsNove = '9v9';

  /// Partita 10 contro 10.
  static const dieciVsDieci = '10v10';

  /// Partita 11 contro 11.
  static const undiciVsUndici = '11v11';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {
    cinqueVsCinque,
    seiVsSei,
    setteVsSette,
    ottoVsOtto,
    noveVsNove,
    dieciVsDieci,
    undiciVsUndici,
  };
}

/// Valori ammessi per `Partita.privacy` (CHECK `partita_privacy_check`).
///
/// Una partita pubblica non appartiene a nessuna lega (associazione 10, CHECK
/// `partita_pubblica_senza_lega_check`): il vincolo lo controlla il database.
abstract final class PrivacyPartita {
  /// Partita visibile anche fuori da una lega.
  static const pubblica = 'pubblica';

  /// Partita riservata agli invitati o ai membri della lega.
  static const privata = 'privata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {pubblica, privata};
}

/// Valori ammessi per `Partita.stato` (CHECK `partita_stato_check`), cioe'
/// gli stati di SCD_PAR_StatoPartita, con le maiuscole dello statechart.
abstract final class StatoPartita {
  /// Partita creata, in attesa di adesioni (stato iniziale, DEFAULT della
  /// colonna).
  static const aperta = 'Aperta';

  /// Raggiunto il numero di partecipanti richiesto.
  static const completa = 'Completa';

  /// Tutte le quote versate.
  static const confermata = 'Confermata';

  /// Partita giocata (stato finale).
  static const conclusa = 'Conclusa';

  /// Partita annullata (stato finale).
  static const annullata = 'Annullata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {aperta, completa, confermata, conclusa, annullata};

  /// Per ogni stato, gli stati raggiungibili con una transizione dello
  /// statechart. E' un dato e non un metodo: eventi, guardie e azioni (D5,
  /// D6, D7, confermaPartita(), gestisciAnnullamento(), avviaPostPartita())
  /// restano in GestionePartitaControl. I due passaggi Completa -> Annullata
  /// dello statechart (annullamento dell'organizzatore e scadenza del
  /// pagamento) diventano una sola coppia. Il passaggio iniziale verso
  /// Aperta non compare: lo realizza il DEFAULT della colonna. Gli stati
  /// finali hanno l'insieme vuoto.
  static const Map<String, Set<String>> transizioniAmmesse = {
    aperta: {completa, annullata},
    completa: {aperta, confermata, annullata},
    confermata: {conclusa, annullata},
    conclusa: <String>{},
    annullata: <String>{},
  };
}

/// Partita di Kickly, letta dalla tabella `partita`.
///
/// `id`, `giocatoreId` e `legaId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della migration B.
class Partita {
  /// Chiave della partita (colonna `id`).
  final String id;

  /// Giocatore organizzatore della partita (colonna `giocatore_id`,
  /// associazione 11).
  final String giocatoreId;

  /// Lega della partita; null per una partita senza lega (associazione 10).
  final String? legaId;

  /// Data e ora di inizio della partita.
  final DateTime dataOra;

  /// Tipologia della partita, uno dei valori di [TipologiaPartita].
  final String tipologia;

  /// Privacy della partita, uno dei valori di [PrivacyPartita].
  final String privacy;

  /// Numero di partecipanti richiesto per completare la partita.
  final int numPartecipantiRichiesti;

  /// Stato della partita, uno dei valori di [StatoPartita].
  final String stato;

  /// Link di condivisione della partita; null se non e' stato generato.
  final String? linkCondivisione;

  /// Crea una Partita con tutti gli attributi del class diagram.
  const Partita({
    required this.id,
    required this.giocatoreId,
    this.legaId,
    required this.dataOra,
    required this.tipologia,
    required this.privacy,
    required this.numPartecipantiRichiesti,
    required this.stato,
    this.linkCondivisione,
  });

  /// Crea una Partita da una riga di `partita` come la restituisce Supabase.
  /// Non valida i valori: li controllano le CHECK del database.
  factory Partita.fromJson(Map<String, dynamic> json) {
    return Partita(
      id: json['id'] as String,
      giocatoreId: json['giocatore_id'] as String,
      legaId: json['lega_id'] as String?,
      dataOra: DateTime.parse(json['data_ora'] as String),
      tipologia: json['tipologia'] as String,
      privacy: json['privacy'] as String,
      numPartecipantiRichiesti: json['num_partecipanti_richiesti'] as int,
      stato: json['stato'] as String,
      linkCondivisione: json['link_condivisione'] as String?,
    );
  }

  /// Converte la Partita nella mappa delle colonne di `partita`, con la data
  /// in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'giocatore_id': giocatoreId,
      'lega_id': legaId,
      'data_ora': dataOra.toUtc().toIso8601String(),
      'tipologia': tipologia,
      'privacy': privacy,
      'num_partecipanti_richiesti': numPartecipantiRichiesti,
      'stato': stato,
      'link_condivisione': linkCondivisione,
    };
  }
}
