// Configurazione dell'app letta in fase di compilazione.
//
// I valori NON sono scritti nel codice: arrivano dal file locale
// `config.json` (ignorato da Git) passato a Flutter con
// `--dart-define-from-file=config.json`. Cosi' le chiavi del progetto
// Supabase non finiscono mai nel repository.
//
// La chiave anon (publishable) puo' stare nell'app perche' i dati sono
// protetti dalle Row Level Security del database. La chiave service_role,
// che aggira le RLS, non deve MAI comparire nell'app ne' nel repo.

/// URL del progetto Supabase (es. `https://<id-progetto>.supabase.co`).
///
/// `String.fromEnvironment` legge il valore a compile time: se la chiave
/// `SUPABASE_URL` non e' stata passata, il valore e' la stringa vuota.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

/// Chiave pubblica anon (publishable) del progetto Supabase.
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Indica se la configurazione di Supabase e' completa.
///
/// Restituisce `false` se [url] o [anonKey] sono vuoti o contengono solo
/// spazi: in quel caso l'app non deve provare a collegarsi a Supabase, ma
/// mostrare un messaggio che spiega come avviarla correttamente.
bool isConfigComplete(String url, String anonKey) {
  return url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
