// Entity GestoreCampo del class diagram (docs/modelli/class.puml).
//
// Specializzazione di Account per chi gestisce una struttura sportiva e
// riceve gli accrediti delle prenotazioni (RF_ACC_1, RF_PAG_2).

import 'account.dart';

/// Gestore di una struttura sportiva: un Account con l'account pagamenti.
///
/// Eredita `id` da Account; nel database la chiave di `gestore_campo` e'
/// `account_id` (class_diagram_sdd.md §3, regola 9). fromJson e toJson usano
/// una mappa piatta con le colonne di `account` e di `gestore_campo`: unire e
/// dividere le due righe e' compito di AccountRepository, non dell'entity.
class GestoreCampo extends Account {
  /// Identificativo dell'account Stripe Connect (modalita' test) collegato
  /// dal Gestore (D3). E' un attributo di dominio, non una chiave; e' null
  /// finche' il collegamento non e' fatto.
  final String? idAccountPagamenti;

  /// Crea un GestoreCampo con gli attributi di Account e l'account pagamenti.
  const GestoreCampo({
    required super.id,
    super.ruoloAccount,
    required super.nome,
    required super.cognome,
    required super.email,
    required super.eta,
    required super.statoAccount,
    required super.statoOnboarding,
    required super.preferenzeNotifiche,
    this.idAccountPagamenti,
  });

  /// Crea un GestoreCampo dalla mappa piatta delle colonne di `account` e di
  /// `gestore_campo`, preparata dal repository. Non valida i valori.
  factory GestoreCampo.fromJson(Map<String, dynamic> json) {
    return GestoreCampo(
      id: json['id'] as String,
      ruoloAccount: json['ruolo_account'] as String?,
      nome: json['nome'] as String,
      cognome: json['cognome'] as String,
      email: json['email'] as String,
      eta: json['eta'] as int,
      statoAccount: json['stato_account'] as String,
      statoOnboarding: json['stato_onboarding'] as String,
      preferenzeNotifiche: json['preferenze_notifiche'] as String,
      idAccountPagamenti: json['id_account_pagamenti'] as String?,
    );
  }

  /// Converte il GestoreCampo nella mappa piatta: le colonne di Account piu'
  /// `id_account_pagamenti`. Il repository la divide e scrive
  /// `account_id = id` nella riga di `gestore_campo`.
  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'id_account_pagamenti': idAccountPagamenti};
  }
}
