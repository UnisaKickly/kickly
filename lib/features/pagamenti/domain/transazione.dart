// Entity Transazione del class diagram (docs/modelli/class.puml).
//
// Registra un pagamento, un rimborso o un accredito e il relativo esito.
// Le chiavi esterne sono tutte facoltative, come le associazioni 0..1 di
// class.puml: la Migration C non lega il tipo di transazione alle chiavi da
// valorizzare. `riferimentoEsterno` e' UNIQUE per
// l'idempotenza (regola 7); la tabella non conserva dati di carta o IBAN.

/// Valori ammessi per `Transazione.tipo`, da class.puml (C19) con la CHECK
/// `transazione_tipo_check`.
abstract final class TipoTransazione {
  /// Pagamento di una quota da parte di un Giocatore.
  static const pagamento = 'pagamento';

  /// Rimborso di un pagamento (RF_PAG_3).
  static const rimborso = 'rimborso';

  /// Accredito al Gestore del Campo.
  static const accredito = 'accredito';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {pagamento, rimborso, accredito};
}

/// Valori ammessi per `Transazione.stato` (CHECK `transazione_stato_check`,
/// D27).
///
/// Solo i valori: i passaggi tra di essi li fa GestioneTransazioniControl.
abstract final class StatoTransazione {
  /// Transazione in attesa (D27).
  static const inAttesa = 'in_attesa';

  /// Transazione completata.
  static const completata = 'completata';

  /// Transazione fallita: un pagamento fallito non addebita nulla.
  static const fallita = 'fallita';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {inAttesa, completata, fallita};
}

/// Transazione di Kickly, letta dalla tabella `transazione`.
///
/// `id`, `quotaId`, `prenotazioneId`, `gestoreCampoId` e
/// `transazioneOriginariaId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della Migration C.
class Transazione {
  /// Chiave della transazione (colonna `id`).
  final String id;

  /// Quota pagata o rimborsata; null se la transazione non riguarda una
  /// quota.
  final String? quotaId;

  /// Prenotazione accreditata (associazione 6); null se non c'e'.
  final String? prenotazioneId;

  /// Gestore del Campo che riceve l'accredito; null se non c'e'.
  final String? gestoreCampoId;

  /// Transazione originaria a cui si riferisce un rimborso (associazione 17);
  /// null se non valorizzata.
  final String? transazioneOriginariaId;

  /// Tipo della transazione, uno dei valori di [TipoTransazione].
  final String tipo;

  /// Importo della transazione.
  final double importo;

  /// Stato della transazione, uno dei valori di [StatoTransazione].
  final String stato;

  /// Data dell'esito; null se non valorizzata (colonna facoltativa nella
  /// Migration C).
  final DateTime? dataEsito;

  /// Identificativo dell'evento del fornitore, unico (regola 7).
  final String riferimentoEsterno;

  /// Crea una Transazione con tutti gli attributi del class diagram.
  const Transazione({
    required this.id,
    this.quotaId,
    this.prenotazioneId,
    this.gestoreCampoId,
    this.transazioneOriginariaId,
    required this.tipo,
    required this.importo,
    required this.stato,
    this.dataEsito,
    required this.riferimentoEsterno,
  });

  /// Crea una Transazione da una riga di `transazione` come la restituisce
  /// Supabase. L'importo puo' arrivare come intero o con decimali: si legge
  /// come num e si converte in double. Non valida i valori: li controllano
  /// le CHECK del database.
  factory Transazione.fromJson(Map<String, dynamic> json) {
    final dataEsito = json['data_esito'] as String?;
    return Transazione(
      id: json['id'] as String,
      quotaId: json['quota_id'] as String?,
      prenotazioneId: json['prenotazione_id'] as String?,
      gestoreCampoId: json['gestore_campo_id'] as String?,
      transazioneOriginariaId: json['transazione_originaria_id'] as String?,
      tipo: json['tipo'] as String,
      importo: (json['importo'] as num).toDouble(),
      stato: json['stato'] as String,
      dataEsito: dataEsito == null ? null : DateTime.parse(dataEsito),
      riferimentoEsterno: json['riferimento_esterno'] as String,
    );
  }

  /// Converte la Transazione nella mappa delle colonne di `transazione`,
  /// con la data dell'esito in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quota_id': quotaId,
      'prenotazione_id': prenotazioneId,
      'gestore_campo_id': gestoreCampoId,
      'transazione_originaria_id': transazioneOriginariaId,
      'tipo': tipo,
      'importo': importo,
      'stato': stato,
      'data_esito': dataEsito?.toUtc().toIso8601String(),
      'riferimento_esterno': riferimentoEsterno,
    };
  }
}
