// Entity Account del class diagram (docs/modelli/class.puml).
//
// Contiene i dati comuni a ogni utente, condivisi dalle specializzazioni
// Giocatore e GestoreCampo. La password non e' un attributo dell'entity:
// la gestisce Supabase Auth (class_diagram_sdd.md §3, regola 2).

/// Valori ammessi per `Account.ruoloAccount`.
///
/// Sono costanti String e non un enum (class_diagram_sdd.md §3, regola 1):
/// gli stessi valori sono controllati dalla CHECK `account_ruolo_account_check`
/// della migration A.
abstract final class RuoloAccount {
  /// Ruolo di chi organizza o partecipa alle partite (RF_ACC_2).
  static const giocatore = 'Giocatore';

  /// Ruolo di chi gestisce una struttura sportiva (RF_ACC_1).
  static const gestoreCampo = 'GestoreCampo';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {giocatore, gestoreCampo};
}

/// Valori ammessi per `Account.statoAccount` (decisione D9).
///
/// `inCancellazione` serve per la cancellazione entro 30 giorni (RNF_L_1).
abstract final class StatoAccount {
  /// Stato di un account in uso; e' il valore alla creazione.
  static const attivo = 'attivo';

  /// Stato di un account di cui e' stata chiesta la cancellazione.
  static const inCancellazione = 'in_cancellazione';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {attivo, inCancellazione};
}

/// Valori ammessi per `Account.statoOnboarding` (decisione D9).
abstract final class StatoOnboarding {
  /// Onboarding non ancora terminato (anche se interrotto, UC_ACC_1 E3);
  /// e' il valore alla creazione.
  static const inCorso = 'in_corso';

  /// Onboarding terminato.
  static const completato = 'completato';

  /// Insieme dei valori ammessi, uguale a quello della CHECK nel database.
  static const valori = {inCorso, completato};
}

/// Dati comuni di un utente di Kickly, letti dalla tabella `account`.
///
/// `id` e' un attributo tecnico di mappatura (class_diagram_sdd.md §3,
/// regola 9): coincide con l'id dell'utente di Supabase Auth.
class Account {
  /// Chiave dell'account (colonna `id`).
  final String id;

  /// Ruolo scelto nell'onboarding; e' null finche' non viene scelto (D11).
  final String? ruoloAccount;

  /// Nome dell'utente.
  final String nome;

  /// Cognome dell'utente.
  final String cognome;

  /// Email dell'utente, copia di quella di Supabase Auth.
  final String email;

  /// Eta' dell'utente, obbligatoria in registrazione (D20).
  final int eta;

  /// Stato dell'account, uno dei valori di [StatoAccount].
  final String statoAccount;

  /// Stato dell'onboarding, uno dei valori di [StatoOnboarding].
  final String statoOnboarding;

  /// Preferenze delle notifiche serializzate in JSON come testo (D10, D18).
  final String preferenzeNotifiche;

  /// Crea un Account con tutti gli attributi del class diagram tranne la
  /// password, che resta in Supabase Auth.
  const Account({
    required this.id,
    this.ruoloAccount,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.eta,
    required this.statoAccount,
    required this.statoOnboarding,
    required this.preferenzeNotifiche,
  });

  /// Crea un Account da una riga della tabella `account` come la restituisce
  /// Supabase. Non valida i valori: li controllano le CHECK del database.
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      ruoloAccount: json['ruolo_account'] as String?,
      nome: json['nome'] as String,
      cognome: json['cognome'] as String,
      email: json['email'] as String,
      eta: json['eta'] as int,
      statoAccount: json['stato_account'] as String,
      statoOnboarding: json['stato_onboarding'] as String,
      preferenzeNotifiche: json['preferenze_notifiche'] as String,
    );
  }

  /// Converte l'Account nella mappa delle colonne di `account`, con le chiavi
  /// della migration A. Non contiene la password.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ruolo_account': ruoloAccount,
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'eta': eta,
      'stato_account': statoAccount,
      'stato_onboarding': statoOnboarding,
      'preferenze_notifiche': preferenzeNotifiche,
    };
  }
}
