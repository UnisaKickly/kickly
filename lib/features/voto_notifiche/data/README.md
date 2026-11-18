# voto_notifiche / data

Sottosistema: **Gestione Voto MVP e Notifiche** (SDD v1.0, §3.2).

Strato Data (Repository, SDD §3.2.2): contiene un Repository per ogni Entity del
sottosistema (Giocatore e GestoreCampo sono gestiti da `AccountRepository`).
I Repository si appoggiano al sottosistema Persistenza (SupabaseClient condiviso in
`lib/core/`) e sono l'unico strato dell'app che puo' usare gli SDK esterni.
