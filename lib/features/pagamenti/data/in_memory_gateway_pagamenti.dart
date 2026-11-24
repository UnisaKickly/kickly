import '../domain/gateway_pagamenti.dart';

// Implementazione in memoria del gateway per test dei Control.
//
// Registra le richieste senza usare servizi esterni: i test verificano che
// il Control disponga una sola volta l'accredito nei casi validi.
class InMemoryGatewayPagamenti implements GatewayPagamenti {
  /// Elenco delle prenotazioni per cui e' stata richiesta la disposizione.
  final List<String> richiesteAccredito = [];

  @override
  /// Registra la richiesta del gateway per il test.
  Future<void> disponiAccredito(String prenotazioneId) async {
    richiesteAccredito.add(prenotazioneId);
  }
}
