import 'dispositivo_registrato.dart';

/// Contratto di persistenza per i dispositivi associati a un Account.
///
/// L'interfaccia non dipende da Supabase: il Control può quindi usare sia
/// l'implementazione remota sia quella in memoria.
abstract interface class DispositivoRepository {
  /// Cerca un dispositivo tramite account proprietario e identificativo.
  Future<DispositivoRegistrato?> findByAccountAndIdentificativo(
    String accountId,
    String identificativo,
  );

  /// Restituisce tutti i dispositivi registrati per un account.
  Future<List<DispositivoRegistrato>> findByAccount(String accountId);

  /// Registra un dispositivo e restituisce la riga persistita.
  Future<DispositivoRegistrato> registerDispositivo(
    String accountId,
    DispositivoRegistrato dispositivo,
  );

  /// Aggiorna la data dell'ultimo accesso del dispositivo.
  Future<void> updateUltimoAccesso(String id, DateTime ultimoAccesso);
}
