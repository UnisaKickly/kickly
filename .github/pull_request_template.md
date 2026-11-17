<!--
  Grazie per la PR! Compila tutte le sezioni: una PR chiara viene revisionata
  (e approvata) molto piu' in fretta. Le righe tra <!-- --> non si vedono.
-->

## Ticket Jira

<!-- Esempio: KCK-12. Il titolo della PR deve iniziare con la stessa chiave. -->
KCK-

## Cosa cambia

<!-- 2-5 righe: cosa hai fatto e perche'. -->

## Come provarlo

<!-- Passi per verificare il lavoro, ad es. "avvia l'app, vai su Profilo, ..."
     Per i documenti: quali sezioni leggere. -->

1.

## Requisito, caso d'uso e artefatti (tracciabilita')

<!-- RF/UC del RAD e file usati come specifica. Esempio:
     RF_LEG_1, UC_LEG_1; docs/rad/uc/UC_LEG_1_*.md, docs/modelli/class.puml (commit a1b2c3d);
     test frame TF_LEG_01-TF_LEG_08 (docs/test/cp_UC_LEG_1.md) -->
- RF / UC:
- Artefatti usati:

## Agenti e modalita'

<!-- Hai usato un agente (Claude Code, Copilot...)? Chi ha approvato il piano? -->
- Agente usato (si/no, quale):
- Piano approvato da:
- Tentativi falliti prima del verde:
- Agente interrotto o passato a una persona (si/no):
- Esito dell'agente revisore (`.claude/agents/revisore.md`): <!-- incolla l'elenco delle differenze e come le hai risolte, oppure "nessuna differenza" -->

## Modifiche ai modelli

<!-- Se hai cambiato class diagram, sequence o RAD, elencalo qui: vanno nella STESSA PR. Altrimenti "nessuna". -->
- Nessuna

## Screenshot (se cambia la UI)

## Checklist

- [ ] Il branch si chiama `<tipo>/KCK-<n>-...` (tipo: feature, fix, chore, docs), parte da `develop` e la PR punta a `develop`
- [ ] Il titolo della PR inizia con la chiave Jira (es. `KCK-12: login con email`)
- [ ] `dart format .`, `flutter analyze` e `flutter test` passano in locale
- [ ] Ho aggiunto/aggiornato i test (se ho scritto codice)
- [ ] Ho aggiornato la documentazione interessata (RAD/SDD/ODD/README) se serve
- [ ] Nessun segreto committato (chiavi, password, `config.json`)
- [ ] Nessun test esistente modificato senza motivazione scritta qui sopra
- [ ] Nessuna nuova dipendenza non approvata da un PM; nessun SDK Supabase/FCM/Stripe in presentation/domain (DG9)
- [ ] **Ho letto e so spiegare tutto il codice di questa PR** (anche quello scritto da un agente)
- [ ] Ho spostato il ticket Jira in **In revisione** e chiesto la review
