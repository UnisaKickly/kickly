# core / errors

Errori condivisi tra i sottosistemi. I Repository (strato Data) traducono le
eccezioni degli SDK esterni e del database in `AppException`
(`app_exception.dart`), cosi' `presentation/` e `domain/` ricevono solo un
messaggio leggibile per l'utente e non dipendono da `supabase_flutter` (DG9).

La traduzione dei casi di Supabase sta in `lib/core/persistence/`
(`translateSupabaseError`): questa cartella non importa nessun SDK.
