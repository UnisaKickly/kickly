# partite / domain

Sottosistema: **Gestione Partite e RSVP** (SDD v1.0, §3.2).

Strato Domain (Control, SDD §3.2.2): contiene le classi Control e le classi Entity
del RAD, cioe' la logica di business del sottosistema. I Control leggono e scrivono
i dati solo attraverso i Repository di `data/`. Le chiamate verso i Control di altri sottosistemi seguono le dipendenze dell'SDD §3.2.1.

Regola DG9: qui NON si importano `supabase_flutter`, `firebase_*` o `flutter_stripe`
(lo verifica la CI). L'accesso a Supabase e ai servizi esterni passa dai Repository in `data/`.
