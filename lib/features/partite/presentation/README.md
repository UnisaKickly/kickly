# partite / presentation

Sottosistema: **Gestione Partite e RSVP** (SDD v1.0, §3.2).

Strato Presentation (GUI, SDD §3.2.2): contiene le classi Boundary del RAD, cioe'
le schermate e i widget con cui l'utente interagisce. Le Boundary chiamano solo le
classi Control di `domain/`.

Regola DG9: qui NON si importano `supabase_flutter`, `firebase_*` o `flutter_stripe`
(lo verifica la CI). L'accesso a Supabase e ai servizi esterni passa dai Repository in `data/`.
