import '../domain/gateway_pagamenti.dart';
import '../domain/quota_repository.dart';
import '../domain/transazione.dart';
import '../domain/transazione_repository.dart';

import 'package:kickly/core/errors/app_exception.dart';

// Eccezione applicativa per l'accredito richiesto prima del versamento di
// tutte le quote della partita.
class QuoteIncompleteException extends AppException {
  /// Crea l'errore leggibile per l'utente.
  QuoteIncompleteException()
    : super(
        message: 'Non tutte le quote della partita sono state versate.',
        code: 'quote_incomplete',
      );
}

// Eccezione applicativa contro il doppio accredito della stessa prenotazione
// (DG2 e RNF_A_3).
class DoppioAccreditoException extends AppException {
  /// Crea l'errore leggibile per l'utente.
  DoppioAccreditoException()
    : super(
        message:
            'L\'accredito per questa prenotazione e\' gia\' stato disposto.',
        code: 'doppio_accredito',
      );
}

/// Coordina la disposizione degli accrediti al Gestore del Campo.
///
/// Il Control applica le guardie definite dal caso d'uso; calcolo del netto,
/// transazioni e passaggi di stato sono gestiti dalle Edge Functions lato
/// server, per rispettare DG1, DG2 e le RLS.
class GestioneTransazioniControl {
  /// Crea il Control con i repository di sola lettura e il gateway.
  GestioneTransazioniControl({
    required this.transazioneRepository,
    required this.quotaRepository,
    required this.gatewayPagamenti,
  });

  final TransazioneRepository transazioneRepository;
  final QuotaRepository quotaRepository;
  final GatewayPagamenti gatewayPagamenti;

  /// Dispone l'accredito dopo aver verificato quote, prenotazione e idempotenza.
  ///
  /// La partita associata alla prenotazione e' verificata tramite le quote
  /// della prenotazione. Lo stato della prenotazione e il collegamento Stripe
  /// sono controllati dalla Edge Function lato server.
  Future<void> disponiAccredito(String prenotazioneId, String partitaId) async {
    final tutteVersate = await quotaRepository.tutteLeQuoteVersate(partitaId);
    if (!tutteVersate) {
      throw QuoteIncompleteException();
    }

    final transazioni = await transazioneRepository.findByPrenotazione(
      prenotazioneId,
    );
    final accreditoEsistente = transazioni.any(
      (transazione) =>
          transazione.tipo == TipoTransazione.accredito &&
          transazione.stato != StatoTransazione.fallita,
    );
    if (accreditoEsistente) {
      throw DoppioAccreditoException();
    }

    await gatewayPagamenti.disponiAccredito(prenotazioneId);
  }

  /// Consulta gli accrediti del Gestore del Campo per la DashboardGestore.
  ///
  /// Non modifica transazioni: restituisce soltanto i dati letti dal repository.
  Future<List<Transazione>> consultaAccrediti(String gestoreCampoId) {
    return transazioneRepository.findByGestoreCampo(gestoreCampoId);
  }
}
