// Interfaccia verso il fornitore di pagamento per gli accrediti.
//
// Il livello Domain usa questa astrazione e non dipende da alcun SDK
// Stripe o da altri dettagli del fornitore esterno.
abstract interface class GatewayPagamenti {
  /// Dispone l'accredito della prenotazione indicata al gestore del campo.
  ///
  /// Il calcolo del netto e la creazione della transazione vengono svolti
  /// dalla Edge Function lato server, con DG1 e DG2.
  Future<void> disponiAccredito(String prenotazioneId);
}
