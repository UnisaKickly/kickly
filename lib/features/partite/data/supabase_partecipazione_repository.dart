import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/partecipazione.dart';
import '../domain/partecipazione_repository.dart';

/// Implementazione Supabase delle sole operazioni di lettura partecipazioni.
///
/// Mantiene un canale Realtime per partita e aggiorna la lista con una nuova
/// lettura REST dopo ogni evento, evitando di affidare l'RSVP al client.
class SupabasePartecipazioneRepository implements PartecipazioneRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabasePartecipazioneRepository(this._client);

  final SupabaseClient _client;

  /// Esegue una lettura Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  @override
  /// Recupera la Partecipazione corrispondente alla chiave indicata.
  Future<Partecipazione?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('partecipazione')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Partecipazione.fromJson(row);
    });
  }

  @override
  /// Restituisce tutte le Partecipazioni della Partita indicata.
  Future<List<Partecipazione>> findByPartita(String partitaId) {
    return _execute(() async {
      final rows = await _client
          .from('partecipazione')
          .select()
          .eq('partita_id', partitaId);
      return rows.map<Partecipazione>(Partecipazione.fromJson).toList();
    });
  }

  @override
  /// Restituisce tutte le Partecipazioni del Giocatore indicato.
  Future<List<Partecipazione>> findByGiocatore(String giocatoreId) {
    return _execute(() async {
      final rows = await _client
          .from('partecipazione')
          .select()
          .eq('giocatore_id', giocatoreId);
      return rows.map<Partecipazione>(Partecipazione.fromJson).toList();
    });
  }

  @override
  /// Recupera la risposta univoca del Giocatore per la Partita indicata.
  Future<Partecipazione?> findByGiocatoreEPartita(
    String giocatoreId,
    String partitaId,
  ) {
    return _execute(() async {
      final row = await _client
          .from('partecipazione')
          .select()
          .eq('giocatore_id', giocatoreId)
          .eq('partita_id', partitaId)
          .maybeSingle();
      return row == null ? null : Partecipazione.fromJson(row);
    });
  }

  @override
  /// Osserva le variazioni delle Partecipazioni e ricarica lo stato dopo ogni evento.
  Stream<List<Partecipazione>> osservaPartecipazioni(String partitaId) {
    // ignore: close_sinks
    late StreamController<List<Partecipazione>> controller;
    RealtimeChannel? channel;

    /// Aggiorna lo stream rileggendo lo stato persistito dopo un evento.
    Future<void> refresh() async {
      try {
        final partecipazioni = await findByPartita(partitaId);
        if (!controller.isClosed) {
          controller.add(partecipazioni);
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(
            translateSupabaseError(error, stackTrace: stackTrace),
          );
        }
      }
    }

    controller = StreamController<List<Partecipazione>>.broadcast(
      onListen: () {
        channel = _client
            .channel('partecipazione:$partitaId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'partecipazione',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'partita_id',
                value: partitaId,
              ),
              callback: (_) {
                unawaited(refresh());
              },
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.channelError ||
                  status == RealtimeSubscribeStatus.timedOut) {
                if (!controller.isClosed) {
                  controller.addError(
                    translateSupabaseError(
                      error ?? StateError('Realtime partecipazioni non attivo'),
                    ),
                  );
                }
              }
            });
        unawaited(refresh());
      },
      onCancel: () async {
        final activeChannel = channel;
        channel = null;
        if (activeChannel != null) {
          await activeChannel.unsubscribe();
        }
      },
    );
    return controller.stream;
  }
}
