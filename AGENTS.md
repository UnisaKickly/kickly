# Kickly

<!-- Agent file: letto in automatico da Claude Code (via CLAUDE.md), Copilot,
     Codex, Cursor. Tienilo BREVE: ogni riga entra nel contesto di ogni
     sessione. Si modifica solo con una PR approvata da un PM (CODEOWNERS). -->

## Contesto
App mobile per organizzare partite di calcio amatoriale: leghe, RSVP, prenotazione
del campo, quote in app (Stripe Connect, solo test), voto MVP, notifiche.
Specifica: RAD v2.9 e SDD v1.0 (Google Drive del team), da cui derivano i file in `docs/`.

## Stack e comandi
Flutter 3.47.0 / Dart, Supabase (PostgreSQL + RLS, Auth, Realtime, Edge Functions in
TypeScript/Deno), Stripe Connect, Firebase Cloud Messaging.
- Dipendenze: `flutter pub get`
- Formato: `dart format .`
- Analisi: `flutter analyze`
- Test: `flutter test`
- Backend locale: `supabase start`, `supabase db reset`, `supabase test db`

## Struttura (SDD 3.2.2: Presentation / Domain / Data)
`lib/features/<sottosistema>/{presentation,domain,data}` con sottosistema in:
`utenza`, `leghe`, `partite`, `voto_notifiche`, `strutture`, `pagamenti`, `sicurezza`.
`lib/core/persistence/` = SupabaseClient condiviso (sottosistema Persistenza).
- presentation = classi Boundary (GUI) del RAD
- domain = classi Control + Entity del RAD
- data = un Repository per ogni Entity (Giocatore e GestoreCampo stanno in AccountRepository)
`supabase/migrations`, `supabase/functions`, `supabase/tests`: database ed Edge Functions.

## Convenzioni
- Nomi di classi, attributi e metodi ESATTAMENTE come in `docs/modelli/class.puml` e nel RAD
  (es. `GestioneLegaControl`, `FormLega`, `LegaRepository`). Niente sinonimi in inglese.
- Branch `<tipo>/KCK-<n>-descrizione`, titolo PR `KCK-<n>: titolo` (vedi CONTRIBUTING.md).
- Commenti in italiano su ogni classe e metodo non banale: cosa fa e perche'.

## Regole
Sempre:
- lavora nel branch del ticket e dentro l'ambito scritto nel ticket;
- proponi un piano (file e metodi) e aspetta l'approvazione di chi ha il ticket prima di scrivere codice;
- un test per ogni test frame (TF) elencato nel ticket, con il TF nel nome del test;
- l'esito atteso di un test viene dal caso d'uso (`docs/rad/uc`), mai dal comportamento del codice.

Chiedi prima:
- classi, metodi o tabelle non presenti nel class diagram o nel RAD;
- modifiche a `lib/core/`, ai repository o alle migration di altri;
- nuove dipendenze in `pubspec.yaml` (il PM verifica che esistano, siano mantenute e con licenza compatibile).

Mai:
- import di `supabase_flutter`, `firebase_*` o `flutter_stripe` in `presentation/` e `domain/` (DG9);
- chiave segreta Stripe, chiavi o password nel repository: solo variabili d'ambiente / secret;
- modificare un test esistente per farlo passare, `skip`, rimuovere asserzioni;
- push su `main` o `develop`, modifiche a `.github/` o a questo file;
- se due modelli sono in contrasto o la specifica manca: NON decidere, fermati e chiedi.
- dopo 3 tentativi falliti sullo stesso errore: fermati e passa il ticket a una persona.

## Quando un task e' finito
`dart format .`, `flutter analyze` e `flutter test` passano; ogni TF del ticket ha un test;
nessun file modificato fuori dall'ambito approvato; PR compilata col template (RF/UC,
artefatti, tentativi, modifiche ai modelli); chi apre la PR sa spiegare ogni riga.

## Documenti di riferimento (leggili solo quando servono)
- `docs/rad/uc/` casi d'uso, `docs/modelli/` class e sequence diagram (PlantUML)
- `docs/sdd/` component e deployment diagram, design goal
- `docs/test/` category partition e test frame
- `CONTRIBUTING.md` flusso Git/Jira
