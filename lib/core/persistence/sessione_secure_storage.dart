// Salvataggio della sessione di Supabase Auth nel Secure Storage del sistema
// operativo (sottosistema Persistenza, KCK-208).
//
// Il deployment diagram dell'SDD (docs/sdd/deployment.puml) e il criterio di
// accettazione di KCK-208 chiedono il token di sessione nel Secure Storage,
// mai in chiaro. Di default supabase_flutter lo salva in SharedPreferences:
// questa classe lo sostituisce e si passa a Supabase.initialize in main.dart.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LocalStorage di supabase_flutter che usa flutter_secure_storage
/// (Keychain su iOS, Keystore su Android).
class SessioneSecureStorage extends LocalStorage {
  /// Crea lo storage; [storage] si passa solo nei test.
  SessioneSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Chiave della sessione salvata: la stessa che usa supabase_flutter.
  static const chiaveSessione = supabasePersistSessionKey;

  @override
  /// Non serve preparare nulla: flutter_secure_storage si apre alla prima
  /// lettura.
  Future<void> initialize() async {}

  @override
  /// Dice se c'e' una sessione salvata (serve all'avvio per riprenderla).
  Future<bool> hasAccessToken() => _storage.containsKey(key: chiaveSessione);

  @override
  /// Restituisce la sessione salvata, serializzata da Supabase Auth.
  Future<String?> accessToken() => _storage.read(key: chiaveSessione);

  @override
  /// Cancella la sessione salvata (logout o sessione non piu' valida).
  Future<void> removePersistedSession() => _storage.delete(key: chiaveSessione);

  @override
  /// Salva la sessione, serializzata da Supabase Auth, dopo login e rinnovo.
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: chiaveSessione, value: persistSessionString);
}
