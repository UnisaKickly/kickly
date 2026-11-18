# leghe / presentation

Sottosistema: **Gestione Leghe e Inviti** (SDD v1.0, §3.2).

Strato Presentation (GUI, SDD §3.2.2): contiene le classi Boundary del RAD, cioe'
le schermate e i widget con cui l'utente interagisce. Le Boundary chiamano solo i Control di `domain/`,
mai direttamente i Repository di `data/` (ordine GUI → Control → Repository). Le chiamate verso i Control di altri sottosistemi seguono le dipendenze dell'SDD §3.2.1.

Regola DG9: qui NON si importano `supabase_flutter`, `firebase_*` o `flutter_stripe`
(lo verifica la CI). L'accesso a Supabase e ai servizi esterni passa dai Repository in `data/`.
