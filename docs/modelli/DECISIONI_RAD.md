# Decisioni sui punti non coperti dal RAD

Questo documento raccoglie le decisioni prese dal team per coprire i punti non specificati nei requisiti funzionali del RAD. **Il RAD e l'SDD restano invariati.**

---

## D1 – Conclusione della partita

* **Problema:** Il RAD dice che "il sistema rileva la conclusione del match" ma nessun RF la descrive.
* **Decisione:** La partita passa a Conclusa da sola quando l'ora di fine e' passata (job pianificato su Supabase, ad es. pg_cron, oppure controllo a lettura nel Control; la scelta viene fatta nel piano del ticket che implementa, non in questo file). Al passaggio si apre la VotazioneMVP e si crea la Notifica di apertura sondaggio. Nessuna nuova schermata e nessuno stato nuovo: usa solo gli stati dello statechart.
* **Ticket coinvolti:** KCK-259 (RF_POS_1, Control del voto MVP), KCK-200 (RF_POS_1, schermate); caso d'uso UC_MVP_1

---

## D2 – Inserimento di gol e assist

* **Problema:** Nessun RF dice come si inseriscono gol e assist (campi di Partecipazione).
* **Decisione:** L'Organizzatore li inserisce per ogni partecipante in DettaglioPartita, solo a partita Conclusa; si implementa in RF_POS_2. Se l'inserimento previsto in RF_POS_2 non viene fatto, classifica e dashboard mostrano gol e assist a 0: e' un comportamento accettato. Non creare nuove entity.
* **Ticket coinvolti:** KCK-209, KCK-217

---

## D3 – Collegamento Stripe del Gestore

* **Problema:** Nessun RF descrive il collegamento dell'account Stripe del Gestore, ma serve all'accredito (RF_PAG_2).
* **Decisione:** Dentro la configurazione della struttura (RF_ACC_1) il Gestore avvia da DashboardGestore il collegamento Stripe (modalita' test) tramite l'azione onboarding_gestore della Edge Function pagamenti; l'identificativo ricevuto si salva in GestoreCampo.idAccountPagamenti. Se il Gestore non ha ancora collegato l'account l'accredito resta 'in attesa' e si completa al collegamento. Nessun dato di carta o IBAN nell'app (DG1). Il nome del metodo non e' nel RAD: viene proposto nel piano del ticket che implementa e fatto approvare.
* **Ticket coinvolti:** KCK-223, KCK-229

---

## D4 – Chi fornisce i dati alla Dashboard partite

* **Problema:** Il RAD prevede la Boundary Dashboard (tabella degli oggetti 3.4.4.1.1: "permette l'accesso alle proprie partite e alle partite pubbliche disponibili") ma non indica quale Control le fornisce l'elenco.
* **Decisione:** Lo fornisce GestionePartitaControl con metodi di sola consultazione (le mie partite; partite pubbliche con posti liberi), usando PartitaRepository e PartecipazioneRepository. Le statistiche della Player Card vengono dal Control di RF_POS_2. Nessuna classe nuova; RAD invariato.
* **Ticket coinvolti:** KCK-264, KCK-235, KCK-203, KCK-209
