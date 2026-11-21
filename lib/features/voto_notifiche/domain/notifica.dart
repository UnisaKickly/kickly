// Entity Notifica del class diagram (docs/modelli/class.puml).
//
// Registra una notifica inviata a un Account (associazione Account 1 —
// 0..* Notifica), con il tipo, il messaggio e lo stato di lettura.

/// Valori ammessi per `Notifica.tipo` (CHECK `notifica_tipo_check`, D27).
///
/// Un nuovo tipo si aggiunge con una migration quando un ticket lo richiede.
abstract final class TipoNotifica {
  /// Apertura del sondaggio MVP (RF_NOT_1).
  static const aperturaSondaggioMVP = 'apertura_sondaggio_mvp';

  /// Apertura delle convocazioni (RF_NOT_1).
  static const aperturaConvocazioni = 'apertura_convocazioni';

  /// Partita confermata (D26).
  static const partitaConfermata = 'partita_confermata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {
    aperturaSondaggioMVP,
    aperturaConvocazioni,
    partitaConfermata,
  };
}

/// Notifica di Kickly, letta dalla tabella `notifica`.
///
/// `id` e `accountId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9), con i nomi della Migration C.
class Notifica {
  /// Chiave della notifica (colonna `id`).
  final String id;

  /// Account destinatario della notifica.
  final String accountId;

  /// Tipo della notifica, uno dei valori di [TipoNotifica].
  final String tipo;

  /// Testo della notifica.
  final String messaggio;

  /// true se la notifica e' stata letta.
  final bool statoLettura;

  /// Data e ora della notifica (colonna `"timestamp"`).
  final DateTime timestamp;

  /// Crea una Notifica con tutti gli attributi del class diagram.
  /// Stato di lettura e timestamp sono obbligatori: i DEFAULT (false e
  /// now()) sono solo nel database, l'entity non contiene logica.
  const Notifica({
    required this.id,
    required this.accountId,
    required this.tipo,
    required this.messaggio,
    required this.statoLettura,
    required this.timestamp,
  });

  /// Crea una Notifica da una riga di `notifica` come la restituisce
  /// Supabase. Non valida i valori: li controllano le CHECK del database.
  factory Notifica.fromJson(Map<String, dynamic> json) {
    return Notifica(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      tipo: json['tipo'] as String,
      messaggio: json['messaggio'] as String,
      statoLettura: json['stato_lettura'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Converte la Notifica nella mappa delle colonne di `notifica`, con il
  /// timestamp in ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'tipo': tipo,
      'messaggio': messaggio,
      'stato_lettura': statoLettura,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
  }
}
