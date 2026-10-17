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

## Screenshot (se cambia la UI)

## Checklist

- [ ] Il branch si chiama `<tipo>/KCK-<n>-...` (tipo: feature, fix, chore, docs), parte da `develop` e la PR punta a `develop`
- [ ] Il titolo della PR inizia con la chiave Jira (es. `KCK-12: login con email`)
- [ ] `dart format .`, `flutter analyze` e `flutter test` passano in locale
- [ ] Ho aggiunto/aggiornato i test (se ho scritto codice)
- [ ] Ho aggiornato la documentazione interessata (RAD/SDD/ODD/README) se serve
- [ ] Nessun segreto committato (chiavi, password, `config.json`)
- [ ] Ho spostato il ticket Jira in **In revisione** e chiesto la review
