// ignore_for_file: close_sinks

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/partecipazione.dart';
import '../domain/partecipazione_repository.dart';

/// Implementazione in memoria di PartecipazioneRepository.
///
/// Fornisce solo letture e osservazione del contratto pubblico; ogni mutazione
/// reale resta esclusa perché l'RSVP deve passare dalla Edge Function.
class InMemoryPartecipazioneRepository implements PartecipazioneRepository {
  /// Crea un repository vuoto con emissioni Realtime simulabili nei test.
  InMemoryPartecipazioneRepository();

  final Map<String, Partecipazione> _partecipazioni = {};
  final Map<String, StreamController<List<Partecipazione>>> _controllers = {};

  /// Aggiunge o sostituisce una partecipazione nella memoria del test.
  void _put(Partecipazione partecipazione) {
    _partecipazioni[partecipazione.id] = partecipazione;
  }

  /// Notifica un canale Realtime simulato con le partecipazioni della partita.
  void _emit(String partitaId) {
    final controller = _controllers[partitaId];
    if (controller == null || controller.isClosed) return;
    controller.add(
      _partecipazioni.values
          .where((partecipazione) => partecipazione.partitaId == partitaId)
          .toList(),
    );
  }

  @override
  /// Recupera la Partecipazione dalla memoria tramite la sua chiave.
  Future<Partecipazione?> findById(String id) async => _partecipazioni[id];

  @override
  /// Restituisce tutte le Partecipazioni della Partita indicata.
  Future<List<Partecipazione>> findByPartita(String partitaId) async {
    return _partecipazioni.values
        .where((partecipazione) => partecipazione.partitaId == partitaId)
        .toList();
  }

  @override
  /// Restituisce tutte le Partecipazioni del Giocatore indicato.
  Future<List<Partecipazione>> findByGiocatore(String giocatoreId) async {
    return _partecipazioni.values
        .where((partecipazione) => partecipazione.giocatoreId == giocatoreId)
        .toList();
  }

  @override
  /// Recupera la risposta univoca del Giocatore per la Partita indicata.
  Future<Partecipazione?> findByGiocatoreEPartita(
    String giocatoreId,
    String partitaId,
  ) async {
    for (final partecipazione in _partecipazioni.values) {
      if (partecipazione.giocatoreId == giocatoreId &&
          partecipazione.partitaId == partitaId) {
        return partecipazione;
      }
    }
    return null;
  }

  @override
  /// Osserva le Partecipazioni della Partita mediante un stream simulato.
  Stream<List<Partecipazione>> osservaPartecipazioni(String partitaId) {
    final existing = _controllers[partitaId];
    if (existing != null && !existing.isClosed) return existing.stream;

    late StreamController<List<Partecipazione>> controller;
    controller = StreamController<List<Partecipazione>>.broadcast(
      onListen: () {
        controller.add(
          _partecipazioni.values
              .where((partecipazione) => partecipazione.partitaId == partitaId)
              .toList(),
        );
      },
      onCancel: () {
        _controllers.remove(partitaId);
      },
    );
    _controllers[partitaId] = controller;
    return controller.stream;
  }

  /// Simula un evento Realtime per i soli test unitari.
  ///
  /// Il metodo ha una mutazione visibile solo ai test e non viene esposto
  /// dall'interfaccia PartecipazioneRepository, preservando il contratto DG3.
  @visibleForTesting
  void simulaAggiornamentoRealtime(
    String partitaId,
    List<Partecipazione> partecipazioni,
  ) {
    for (final partecipazione in _partecipazioni.values.toList()) {
      if (partecipazione.partitaId == partitaId) {
        _partecipazioni.remove(partecipazione.id);
      }
    }
    for (final partecipazione in partecipazioni) {
      _put(partecipazione);
    }
    _emit(partitaId);
  }
}
