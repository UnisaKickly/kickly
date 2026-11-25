// Entity Giocatore del class diagram (docs/modelli/class.puml).
//
// Specializzazione di Account per chi organizza o partecipa alle partite.
// Le statistiche della Player Card non sono attributi: si calcolano da
// Partecipazione e VotazioneMVP (tabella degli oggetti del RAD).

import 'account.dart';

/// Giocatore di Kickly: un Account con i dati della Player Card.
///
/// Eredita `id` da Account; nel database la chiave di `giocatore` e'
/// `account_id` (class_diagram_sdd.md §3, regola 9). fromJson e toJson usano
/// una mappa piatta con le colonne di `account` e di `giocatore`: unire e
/// dividere le due righe e' compito di AccountRepository, non dell'entity.
class Giocatore extends Account {
  /// Ruolo preferito in campo; null finche' la Player Card non e' salvata
  /// (SD_UC_ACC_1: la riga nasce alla scelta del ruolo, la Player Card dopo).
  final String? ruoloPreferitoInCampo;

  /// Piede dominante; null finche' la Player Card non e' salvata.
  final String? piedeDominante;

  /// Crea un Giocatore con gli attributi di Account e quelli della Player Card.
  const Giocatore({
    required super.id,
    super.ruoloAccount,
    required super.nome,
    required super.cognome,
    required super.email,
    required super.eta,
    required super.statoAccount,
    required super.statoOnboarding,
    required super.preferenzeNotifiche,
    this.ruoloPreferitoInCampo,
    this.piedeDominante,
  });

  /// Crea un Giocatore dalla mappa piatta delle colonne di `account` e di
  /// `giocatore`, preparata dal repository. Non valida i valori.
  factory Giocatore.fromJson(Map<String, dynamic> json) {
    return Giocatore(
      id: json['id'] as String,
      ruoloAccount: json['ruolo_account'] as String?,
      nome: json['nome'] as String,
      cognome: json['cognome'] as String,
      email: json['email'] as String,
      eta: json['eta'] as int,
      statoAccount: json['stato_account'] as String,
      statoOnboarding: json['stato_onboarding'] as String,
      preferenzeNotifiche: json['preferenze_notifiche'] as String,
      ruoloPreferitoInCampo: json['ruolo_preferito_in_campo'] as String?,
      piedeDominante: json['piede_dominante'] as String?,
    );
  }

  /// Converte il Giocatore nella mappa piatta: le colonne di Account piu'
  /// quelle della Player Card. Il repository la divide e scrive
  /// `account_id = id` nella riga di `giocatore`.
  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'ruolo_preferito_in_campo': ruoloPreferitoInCampo,
      'piede_dominante': piedeDominante,
    };
  }
}
