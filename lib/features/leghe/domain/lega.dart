// Entity Lega del class diagram (docs/modelli/class.puml).
//
// Raccoglie i dati di una lega e del relativo codice di invito. Membri e
// amministratori (associazioni molti-a-molti) non sono attributi dell'entity:
// le tabelle `membro_lega` e `amministratore_lega` le gestisce LegaRepository.

/// Valori ammessi per `Lega.tipologiaMatch`.
///
/// Costanti String e non un enum (class_diagram_sdd.md §3, regola 1), con i
/// valori della CHECK `lega_tipologia_match_check`. I nomi sono in lettere
/// perche' in Dart un identificatore non puo' iniziare con una cifra. La
/// conversione verso il formato "5vs5" dei casi d'uso non e' compito
/// dell'entity.
abstract final class TipologiaMatch {
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

/// Valori ammessi per `Lega.privacy` (CHECK `lega_privacy_check`).
abstract final class PrivacyLega {
  /// Lega a cui si puo' aderire senza invito (UC_LEG_1 A1).
  static const pubblica = 'pubblica';

  /// Lega a cui si accede solo con un invito.
  static const privata = 'privata';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {pubblica, privata};
}

/// Lega di Kickly, letta dalla tabella `lega`.
///
/// `id` e' un attributo tecnico di mappatura (class_diagram_sdd.md §3,
/// regola 9).
class Lega {
  /// Chiave della lega (colonna `id`).
  final String id;

  /// Nome della lega, unico (D21, vincolo nel database).
  final String nome;

  /// Tipologia delle partite della lega, uno dei valori di [TipologiaMatch].
  final String tipologiaMatch;

  /// Privacy della lega, uno dei valori di [PrivacyLega].
  final String privacy;

  /// Codice di invito; null se non e' stato generato.
  final String? codiceInvito;

  /// Scadenza del codice di invito; null insieme a [codiceInvito].
  final DateTime? scadenzaCodiceInvito;

  /// Crea una Lega con tutti gli attributi del class diagram.
  const Lega({
    required this.id,
    required this.nome,
    required this.tipologiaMatch,
    required this.privacy,
    this.codiceInvito,
    this.scadenzaCodiceInvito,
  });

  /// Crea una Lega da una riga di `lega` come la restituisce Supabase.
  /// Non valida i valori: li controllano le CHECK del database.
  factory Lega.fromJson(Map<String, dynamic> json) {
    final scadenza = json['scadenza_codice_invito'] as String?;
    return Lega(
      id: json['id'] as String,
      nome: json['nome'] as String,
      tipologiaMatch: json['tipologia_match'] as String,
      privacy: json['privacy'] as String,
      codiceInvito: json['codice_invito'] as String?,
      scadenzaCodiceInvito: scadenza == null ? null : DateTime.parse(scadenza),
    );
  }

  /// Converte la Lega nella mappa delle colonne di `lega`, con la scadenza in
  /// ISO 8601 UTC.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'tipologia_match': tipologiaMatch,
      'privacy': privacy,
      'codice_invito': codiceInvito,
      'scadenza_codice_invito': scadenzaCodiceInvito?.toUtc().toIso8601String(),
    };
  }
}
