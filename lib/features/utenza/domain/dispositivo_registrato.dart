// Entity DispositivoRegistrato del class diagram (docs/modelli/class.puml).
//
// Registra i dispositivi da cui un Account accede, con primo e ultimo
// accesso (associazione Account 1 — 0..* DispositivoRegistrato).

/// Dispositivo associato a un Account, letto da `dispositivo_registrato`.
///
/// `id` e `accountId` sono attributi tecnici di mappatura
/// (class_diagram_sdd.md §3, regola 9).
class DispositivoRegistrato {
  /// Chiave del dispositivo (colonna `id`).
  final String id;

  /// Chiave esterna verso l'Account proprietario (colonna `account_id`).
  final String accountId;

  /// Identificativo del dispositivo, unico per Account.
  final String identificativo;

  /// Data e ora del primo accesso dal dispositivo.
  final DateTime primoAccesso;

  /// Data e ora dell'ultimo accesso dal dispositivo.
  final DateTime ultimoAccesso;

  /// Crea un DispositivoRegistrato con tutti gli attributi.
  const DispositivoRegistrato({
    required this.id,
    required this.accountId,
    required this.identificativo,
    required this.primoAccesso,
    required this.ultimoAccesso,
  });

  /// Crea un DispositivoRegistrato da una riga di `dispositivo_registrato`
  /// come la restituisce Supabase (date ISO 8601, es. "...+00:00").
  factory DispositivoRegistrato.fromJson(Map<String, dynamic> json) {
    return DispositivoRegistrato(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      identificativo: json['identificativo'] as String,
      primoAccesso: DateTime.parse(json['primo_accesso'] as String),
      ultimoAccesso: DateTime.parse(json['ultimo_accesso'] as String),
    );
  }

  /// Converte il DispositivoRegistrato nella mappa delle colonne, con le date
  /// in ISO 8601 UTC, il formato accettato da `timestamptz`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_id': accountId,
      'identificativo': identificativo,
      'primo_accesso': primoAccesso.toUtc().toIso8601String(),
      'ultimo_accesso': ultimoAccesso.toUtc().toIso8601String(),
    };
  }
}
