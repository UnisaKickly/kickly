# utenza / data

Sottosistema: **Gestione Utenza** (SDD v1.0, §3.2).

Strato Data (Repository, SDD §3.2.2): contiene un Repository per ogni Entity del
sottosistema (Giocatore e GestoreCampo sono gestiti da `AccountRepository`).
I Repository si appoggiano al sottosistema Persistenza.

Gli SDK esterni (Supabase, FCM, Stripe) si usano solo in data/ e in lib/core/ (DG9).
