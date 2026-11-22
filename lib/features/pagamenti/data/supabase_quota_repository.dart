import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/supabase_client_provider.dart';
import '../domain/quota.dart';
import '../domain/quota_repository.dart';

/// Implementazione Supabase del repository delle quote.
///
/// Mappa la tabella `quota` nell'entity e usa il join PostgREST con
/// `partecipazione` per filtrare le quote della partita. Le scritture sono
/// esposte al Control ma in produzione sono protette dalle policy RLS C e dalle
/// Edge Functions per DG1 e DG2.
class SupabaseQuotaRepository implements QuotaRepository {
  /// Crea il repository usando il client Supabase condiviso.
  SupabaseQuotaRepository(this._client);

  final SupabaseClient _client;

  /// Esegue una chiamata Supabase traducendo gli errori in AppException.
  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      throw translateSupabaseError(error, stackTrace: stackTrace);
    }
  }

  /// Seleziona le colonne della quota e il vincolo interno alla partecipazione.
  static const String _quotaConPartecipazione =
      '*, partecipazione!inner(partita_id)';

  @override
  /// Cerca una quota tramite la chiave primaria della tabella.
  Future<Quota?> findById(String id) {
    return _execute(() async {
      final row = await _client
          .from('quota')
          .select()
          .eq('id', id)
          .maybeSingle();
      return row == null ? null : Quota.fromJson(row);
    });
  }

  @override
  /// Legge la quota tramite la chiave, con lo stesso comportamento di findById.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`.
  Future<Quota?> leggiQuota(String quotaId) => findById(quotaId);

  @override
  /// Cerca l'unica quota collegata alla partecipazione indicata.
  Future<Quota?> findByPartecipazione(String partecipazioneId) {
    return _execute(() async {
      final row = await _client
          .from('quota')
          .select()
          .eq('partecipazione_id', partecipazioneId)
          .maybeSingle();
      return row == null ? null : Quota.fromJson(row);
    });
  }

  @override
  /// Restituisce le quote da versare filtrando le partecipazioni della partita.
  Future<List<Quota>> findDaVersareByPartita(String partitaId) {
    return _execute(() async {
      final rows = await _client
          .from('quota')
          .select(_quotaConPartecipazione)
          .eq('partecipazione.partita_id', partitaId)
          .eq('stato_versamento', StatoVersamento.daVersare);
      return rows.map<Quota>(Quota.fromJson).toList();
    });
  }

  @override
  /// Conta le quote da versare della partita usando il join alla partecipazione.
  Future<int> countDaVersareByPartita(String partitaId) {
    return _execute(() async {
      final rows = await _client
          .from('quota')
          .select(_quotaConPartecipazione)
          .eq('partecipazione.partita_id', partitaId)
          .eq('stato_versamento', StatoVersamento.daVersare);
      return rows.length;
    });
  }

  @override
  /// Inserisce la quota senza inviare l'id: lo assegna il database.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' destinato alle Edge
  /// Functions con service role o ai test dei Control con InMemoryQuotaRepository.
  Future<Quota> createQuota(Quota quota) {
    return _execute(() async {
      final json = quota.toJson()..remove('id');
      final row = await _client.from('quota').insert(json).select().single();
      return Quota.fromJson(row);
    });
  }

  @override
  /// Aggiorna il solo stato della quota, senza cambiare importo o partecipante.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' destinato alle Edge
  /// Functions con service role o ai test dei Control con InMemoryQuotaRepository.
  Future<void> updateStatoVersamento(String id, String statoVersamento) {
    return _execute(() async {
      await _client
          .from('quota')
          .update({'stato_versamento': statoVersamento})
          .eq('id', id);
    });
  }

  @override
  /// Registra il versamento impostando `stato_versamento` a `versata`.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' destinato alle Edge
  /// Functions con service role o ai test dei Control con InMemoryQuotaRepository.
  Future<void> registraVersamento(String quotaId) {
    return updateStatoVersamento(quotaId, StatoVersamento.versata);
  }

  @override
  /// Elimina la quota solo se il suo stato e' ancora da_versare.
  ///
  /// Con le policy RLS di KCK-233 su Supabase il client autenticato ha solo
  /// permessi di lettura su `quota`; eventuali scritture dirette da client
  /// restituiscono errore `42501`. Questo metodo e' destinato alle Edge
  /// Functions con service role o ai test dei Control con InMemoryQuotaRepository.
  Future<void> deleteDaVersare(String id) {
    return _execute(() async {
      await _client
          .from('quota')
          .delete()
          .eq('id', id)
          .eq('stato_versamento', StatoVersamento.daVersare);
    });
  }

  @override
  /// Verifica che non esistano quote da versare per la partita indicata.
  Future<bool> tutteLeQuoteVersate(String partitaId) {
    return _execute(() async {
      final rows = await _client
          .from('quota')
          .select(_quotaConPartecipazione)
          .eq('partecipazione.partita_id', partitaId)
          .eq('stato_versamento', StatoVersamento.daVersare);
      return rows.isEmpty;
    });
  }
}
