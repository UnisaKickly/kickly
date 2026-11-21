import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/campo.dart';
import '../domain/campo_repository.dart';

/// Implementazione Supabase del repository dei campi.
///
/// Traduce gli errori tecnici in AppException e usa solo la tabella `campo`,
/// senza esporre Supabase agli strati Domain o Presentation.
class SupabaseCampoRepository implements CampoRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabaseCampoRepository(this._client);

  final SupabaseClient _client;

  /// Esegue un'operazione Supabase e traduce eventuali eccezioni applicative.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Mappa i campi persistiti escludendo l'identificativo tecnico dalla create.
  Map<String, dynamic> _columns(Campo campo) => {
    'gestore_campo_id': campo.gestoreCampoId,
    'nome': campo.nome,
    'ubicazione': campo.ubicazione,
    'tariffa_oraria': campo.tariffaOraria,
    'orari_disponibilita': campo.orariDisponibilita,
  };

  @override
  /// Recupera il Campo corrispondente alla chiave indicata.
  Future<Campo?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('campo')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Campo.fromJson(row);
    });
  }

  @override
  /// Restituisce i campi associati al GestoreCampo indicato.
  Future<List<Campo>> findByGestoreCampo(String gestoreCampoId) {
    return _execute(() async {
      final rows = await _client
          .from('campo')
          .select()
          .eq('gestore_campo_id', gestoreCampoId);
      return rows.map<Campo>(Campo.fromJson).toList();
    });
  }

  @override
  /// Inserisce un nuovo Campo assegnandone l'identificativo al database.
  Future<Campo> createCampo(Campo campo) {
    return _execute(() async {
      final row = await _client
          .from('campo')
          .insert(_columns(campo))
          .select()
          .single();
      return Campo.fromJson(row);
    });
  }

  @override
  /// Aggiorna i dati persistiti del Campo esistente.
  Future<Campo> updateCampo(Campo campo) {
    return _execute(() async {
      final row = await _client
          .from('campo')
          .update(_columns(campo))
          .eq('id', campo.id)
          .select()
          .single();
      return Campo.fromJson(row);
    });
  }

  @override
  /// Elimina il Campo corrispondente alla chiave indicata.
  Future<void> deleteCampo(String id) {
    return _execute(() async {
      await _client.from('campo').delete().eq('id', id);
    });
  }

  @override
  /// Legge gli orari di disponibilita' del Campo.
  Future<String?> getDisponibilita(String campoId) {
    return _execute(() async {
      final row = await _client
          .from('campo')
          .select('orari_disponibilita')
          .eq('id', campoId)
          .maybeSingle();
      return row == null ? null : row['orari_disponibilita'] as String?;
    });
  }

  @override
  /// Legge la tariffa oraria del Campo.
  Future<double?> getTariffa(String campoId) {
    return _execute(() async {
      final row = await _client
          .from('campo')
          .select('tariffa_oraria')
          .eq('id', campoId)
          .maybeSingle();
      if (row == null) return null;
      return (row['tariffa_oraria'] as num).toDouble();
    });
  }
}
