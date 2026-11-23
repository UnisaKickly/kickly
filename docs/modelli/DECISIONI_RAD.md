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

---

## D5 – Tempo limite per annullare una partita

* **Problema:** RF_PAR_3 permette all'Organizzatore di annullare "entro un tempo limite prestabilito", ma il RAD non dice quanto vale ne' cosa succede oltre il limite.
* **Decisione:** Il limite e' 24 ore prima dell'inizio della partita (Partita.dataOra). Oltre il limite il comando di annullamento non e' disponibile in DettaglioPartita e una richiesta di annullamento viene rifiutata con un messaggio di errore: la partita resta nel suo stato, non parte nessuna notifica e lo slot resta prenotato. Vale per le guardie [entro termine] dello statechart.
* **Ticket coinvolti:** KCK-197, KCK-205; test frame TF_PAR_10, TF_PAR_11, TF_PAG_10, TF_PAG_12 (KCK-240)

---

## D6 – Chi possiede l'annullamento della partita

* **Problema:** L'azione gestisciAnnullamento() dello statechart non ha una classe; le tabelle degli oggetti del RAD danno l'annullamento sia a GestionePartitaControl sia a GestioneTransazioniControl.
* **Decisione:** gestisciAnnullamento() e' un metodo di GestionePartitaControl: porta la partita ad Annullata, fa liberare lo slot da PrenotazioneControl e chiede a GestioneTransazioniControl i rimborsi delle quote gia' versate (RF_PAG_3). Rispetta la dipendenza ammessa Partite -> Pagamenti di component.puml; non si aggiunge la dipendenza inversa. L'annullamento per scadenza del pagamento lo rileva il server (job o Edge Function, come in D1) e usa lo stesso flusso. Come arriva la notifica di cancellazione agli iscritti lo propone il piano di KCK-197, nel rispetto delle dipendenze di component.puml.
* **Ticket coinvolti:** KCK-197, KCK-237, KCK-214

---

## D7 – Parametri non validi nella creazione della partita

* **Problema:** UC_PAR_1 non ha un flusso di errore per parametri mancanti o non validi.
* **Decisione:** Come in UC_ACC_1 E2 e UC_LEG_1 E1: il sistema mostra un messaggio di errore sul campo da correggere, non crea la partita e non verifica lo slot; l'utente resta su FormCreazionePartita. Sono non validi: un campo obbligatorio vuoto, data/ora nel passato, numero di partecipanti inferiore ai giocatori in campo della tipologia (es. meno di 10 per il 5vs5).
* **Ticket coinvolti:** KCK-235, KCK-241; test frame TF_PAR_12 (KCK-240)

---

## D8 – Messaggi per RSVP a capienza raggiunta e quota gia' versata

* **Problema:** Il RAD impedisce l'overbooking e il doppio versamento, ma non dice cosa vede il Giocatore.
* **Decisione:** RSVP con partita al completo: la risposta non viene registrata e il Giocatore vede "Partita al completo". Quota gia' versata: in DettaglioPartita il comando di pagamento non e' disponibile e compare "Quota gia' versata"; nessun nuovo addebito.
* **Ticket coinvolti:** KCK-248, KCK-254, KCK-214, KCK-220; test frame TF_PAR_06, TF_PAG_07 (KCK-240)

---

## D9 – Valori di statoAccount e statoOnboarding

* **Problema:** Il class diagram dice che gli attributi di stato sono String con un CHECK, ma il RAD non elenca i valori di `Account.statoAccount` e `Account.statoOnboarding`.
* **Decisione:** `statoOnboarding` ammette `in_corso` e `completato`: lo UC_ACC_1 prevede un onboarding che resta incompleto se l'utente abbandona (E3) e che al termine e' completato. `statoAccount` ammette `attivo` e `in_cancellazione`: RNF_L_1 chiede la cancellazione entro 30 giorni dalla richiesta, quindi serve uno stato intermedio. Alla creazione: `attivo` e `in_corso`. Nel DB sono due CHECK, in Dart due insiemi di costanti. Nessun altro valore senza chiedere ai PM.
* **Ticket coinvolti:** KCK-202, KCK-196; KCK-204 e KCK-212 (cancellazione account)

---

## D10 – Tipo di preferenzeNotifiche nel database

* **Problema:** Nel class diagram `Account.preferenzeNotifiche` e' String, ma la migration A lo aveva scritto come `jsonb`.
* **Decisione:** Si resta sul class diagram (regola 1 e regola generale di `class_diagram_sdd.md` §3): la colonna e' `text NOT NULL DEFAULT '{}'` e contiene le preferenze serializzate in JSON da `AccountRepository`. Nessuna modifica ai modelli. Se serviranno interrogazioni sul contenuto, si usa il cast `::jsonb` nella query, senza cambiare il tipo.
* **Ticket coinvolti:** KCK-202, KCK-196; RF_NOT_2

---

## D11 – Ruolo e specializzazione dell'Account

* **Problema:** `ruolo_account` e le tabelle `giocatore` e `gestore_campo` non sono legate nel database, mentre RF_ACC_1 e RF_ACC_2 dicono che la scelta del ruolo e' definitiva.
* **Decisione:** Il vincolo non si mette in un trigger della migration. `ruolo_account` resta nullo fino all'onboarding e lo imposta una sola volta il Control di registrazione, che crea nello stesso passo la riga di `giocatore` o di `gestore_campo`. Che il ruolo non si possa piu' modificare si garantisce con le policy RLS, che nel ticket RLS vietano l'aggiornamento di `ruolo_account` quando e' gia' valorizzato.
* **Ticket coinvolti:** KCK-202; KCK-250 (RF_ACC_2); ticket RLS
* **Aggiornamento (23/11/2026, KCK-226):** il vincolo si realizza con un trigger nella migration RLS e non con le policy, perche' una policy RLS non confronta il valore precedente con quello nuovo (decisione dei PM). Il trigger `account_ruolo_definitivo` (funzione `verifica_cambio_ruolo_account()`) rifiuta il cambio di `ruolo_account` quando `stato_onboarding` e' `completato`, e rifiuta il ritorno di `stato_onboarding` da `completato` a `in_corso`, che permetterebbe di aggirare la regola (D9 prevede solo `in_corso` -> `completato`). Finche' l'onboarding e' `in_corso` e non esiste ancora la riga di specializzazione il ruolo si puo' ancora modificare. Inoltre (decisione dei PM dopo la revisione di KCK-226) il database rifiuta, anche per il server, il cambio di `ruolo_account` se esiste gia' la riga di `giocatore` o di `gestore_campo`, l'inserimento in `giocatore` o `gestore_campo` se `ruolo_account` non corrisponde, e il passaggio di `stato_onboarding` a `completato` senza la riga di specializzazione corrispondente.

---

## D12 – Cancellazione dell'unico amministratore di una lega

* **Problema:** Il class diagram prevede 1..* amministratori per lega, ma la cancellazione dell'account dell'unico amministratore (RNF_L_1) puo' lasciare la lega senza amministratori, e il RAD non dice cosa succede.
* **Decisione:** La cancellazione dei dati personali non si blocca mai: la migration lascia quindi passare questo caso (come fa gia' il trigger di integrita', e la scelta e' da commentare in italiano nel codice SQL). Come si risolve la lega (promozione di un membro o cancellazione della lega) lo decide `CancellazioneAccountControl` nel suo ticket, con un piano approvato dai PM prima di scrivere codice. Nessuna nuova colonna e nessuna nuova schermata decise qui.
* **Ticket coinvolti:** KCK-202; KCK-204, KCK-212
* **Aggiornamento (19/11/2026):** come si risolve la lega e' stato deciso dai PM in D19.

---

## D13 – Operazioni non permesse e comandi riservati

* **Problema:** Il RAD prevede operazioni riservate (all'amministratore della lega, ai partecipanti di una partita, agli iscritti di una partita pubblica) e entry condition che le limitano, ma non dice cosa vede chi non ha il permesso.
* **Decisione:** Regola unica per tutti i casi d'uso: il comando non e' visibile a chi non puo' usarlo (come gia' dice la tabella degli oggetti per DashboardLega: "i comandi riservati agli amministratori"); se la richiesta arriva comunque (es. chiamata diretta), il Control la rifiuta con un messaggio di errore e non modifica nulla. Vale per: voto su partita non Conclusa o da non partecipante (UC_MVP_1), condivisione di partita non pubblica o da non iscritto (UC_SS_1), modifica della lega, generazione dell'invito e gestione membri da parte di un non amministratore (RF_LEG_1..3). Il controllo lato server resta nelle policy RLS.
* **Ticket coinvolti:** KCK-259, KCK-200, KCK-251, KCK-255, KCK-242, KCK-249, KCK-256, KCK-199, KCK-222, KCK-228; test frame TF_MVP_03, TF_MVP_04, TF_SS_05, TF_SS_06 (KCK-247), TF_LEG_07, TF_LEG_11, TF_LEG_23 (KCK-232)

---

## D14 – Voto MVP: autovoto non ammesso

* **Problema:** UC_MVP_1 mostra "l'elenco dei giocatori partecipanti" (passo 2) ma non dice se il votante puo' votare se stesso.
* **Decisione:** L'autovoto non e' ammesso: il votante non compare nell'elenco dei giocatori votabili. Una richiesta di voto per se stessi viene rifiutata con un messaggio di errore e il voto non e' registrato.
* **Ticket coinvolti:** KCK-259, KCK-200; test frame TF_MVP_07 (KCK-247)

---

## D15 – Classifica: lista vuota e ordine a parita' di titoli

* **Problema:** RF_POS_2 chiede la classifica dei giocatori con piu' titoli MVP e le relative statistiche, ma non dice cosa mostrare se non ci sono titoli ne' come ordinare i pari merito.
* **Decisione:** Senza titoli MVP assegnati la classifica mostra il messaggio "Nessuna classifica disponibile". L'ordine e': titoli MVP vinti, poi voti ricevuti, poi gol, poi assist, poi ordine alfabetico del nome (sono i dati che la tabella degli oggetti attribuisce a ClassificaControl). Gol e assist non inseriti valgono 0 (D2).
* **Ticket coinvolti:** KCK-209, KCK-217; test frame TF_MVP_09, TF_MVP_11 (KCK-247)

---

## D16 – Player Card incompleta, login fallito e recupero password

* **Problema:** UC_ACC_1 non dice cosa succede se la Player Card viene confermata incompleta; RF_ACC_3 e RF_ACC_4 non hanno un caso d'uso e non descrivono gli esiti di errore.
* **Decisione:**
  * Player Card senza ruolo in campo o piede dominante: come UC_ACC_1 E2, errore sul campo, si resta sulla configurazione e la Player Card non viene salvata.
  * Login fallito: lo stesso messaggio generico "Email o password non corretti" per email non registrata e per password errata, cosi' non si rivela quali email sono registrate; campo vuoto: errore sul campo. In ogni caso si resta su FormLogin senza autenticare.
  * Recupero password con email non associata: lo stesso messaggio del caso valido ("Se l'email e' registrata riceverai un messaggio") e nessuna email inviata.
  * Collegamento di recupero scaduto o non valido: messaggio "Collegamento scaduto o non valido", password invariata, si ripete la richiesta di recupero.
  * Nuova password debole nel recupero: stesso controllo e stesso tipo di messaggio di UC_ACC_1 E2; si resta sul modulo.
* **Ticket coinvolti:** KCK-250, KCK-198, KCK-208, KCK-215, KCK-234, KCK-262; test frame TF_ACC_07, TF_ACC_11-13, TF_ACC_16-18 (KCK-232)

---

## D17 – Leghe: nome gia' in uso in modifica, gia' membro, unico amministratore, non membro

* **Problema:** UC_LEG_1 e RF_LEG_1..4 non dicono cosa succede in quattro casi limite.
* **Decisione:**
  * Rinominare la lega con un nome gia' in uso: come UC_LEG_1 E1 (errore, campo evidenziato, si resta su FormLega, nessuna modifica).
  * Codice o link usato da chi e' gia' membro: messaggio "Sei gia' membro di questa lega", nessuna nuova adesione.
  * L'unico amministratore non puo' rimuovere se stesso: il class diagram prevede almeno un amministratore per lega (1..*); la richiesta e' rifiutata con "Nomina un altro amministratore prima di uscire". La cancellazione dell'account resta regolata da D12.
  * Un non membro che apre una lega non vede la DashboardLega: per una lega pubblica vede il comando per unirsi (UC_LEG_1 A1), per una privata il messaggio "Lega privata: serve un invito".
* **Ticket coinvolti:** KCK-242, KCK-249, KCK-256, KCK-199, KCK-222, KCK-228, KCK-207, KCK-216; test frame TF_LEG_08, TF_LEG_16, TF_LEG_22, TF_LEG_25 (KCK-232)

---

## D18 – Significato di "personalizzare" le notifiche

* **Problema:** RF_NOT_2 permette di "attivare, disattivare o personalizzare le tipologie di notifiche da ricevere", ma il RAD non dice cosa significhi "personalizzare" oltre ad attivare e disattivare.
* **Decisione:** "Personalizzare" significa scegliere, tipologia per tipologia, quali notifiche ricevere: non e' un'operazione diversa da attivare o disattivare una singola tipologia. Le preferenze sono salvate in `Account.preferenzeNotifiche` (D10); una tipologia disattivata non genera notifiche per quell'Account. Nessun altro parametro (canale, orari) senza chiedere ai PM.
* **Ticket coinvolti:** KCK-202, KCK-196 (RF_NOT_2); test frame TF_NOT_02, TF_NOT_05, TF_NOT_06 (KCK-247)

---

## D19 – Lega dell'unico amministratore che cancella l'account

* **Problema:** D12 non blocca la cancellazione dell'unico amministratore di una lega, ma lasciava al ticket di CancellazioneAccountControl la scelta su cosa succede alla lega; il class diagram richiede almeno un amministratore (1..*).
* **Decisione:** Se nella lega restano altri membri, diventa amministratore il membro con piu' presenze confermate nelle partite della lega (Partecipazione con risposta confermata); a parita', il primo in ordine alfabetico di cognome e nome. Se non resta nessun altro membro, la lega viene cancellata. Si calcola con i dati esistenti: nessuna nuova colonna e nessuna modifica al class diagram o alla migration A.
* **Ticket coinvolti:** KCK-204, KCK-212 (CancellazioneAccountControl); test frame TF_SS_11, TF_SS_12 (KCK-247)

---

## D20 – Eta' in registrazione

* **Problema:** UC_ACC_1 chiede l'eta' nel modulo di registrazione (passo 2) ma il RAD non dice se e' obbligatoria ne' se c'e' un'eta' minima.
* **Decisione:** L'eta' e' obbligatoria e deve essere di almeno 14 anni (eta' minima in Italia per dare da soli il consenso ai servizi online, GDPR art. 8; limite superiore 120). Una registrazione senza eta' o con eta' fuori intervallo e' un caso di UC_ACC_1 E2 (dati non validi). Nel database: `account.eta` NOT NULL con CHECK.
* **Ticket coinvolti:** KCK-202, KCK-250, KCK-198; test frame TF_ACC_03 (KCK-232)

---

## D21 – Unicita' del nome della lega

* **Problema:** UC_LEG_1 E1 prevede l'errore "nome lega gia' in uso" ma non dice se due nomi che differiscono solo per maiuscole o spazi sono lo stesso nome.
* **Decisione:** Il nome della lega e' unico senza distinguere maiuscole e spazi iniziali/finali ("Champions Giovedi'" e "champions giovedi' " sono lo stesso nome). Nel database: indice UNIQUE su `lower(btrim(nome))` e CHECK sul nome non vuoto, cosi' il controllo regge anche a due creazioni contemporanee; il Control mostra l'errore di E1. Vale anche per la modifica (D17).
* **Ticket coinvolti:** KCK-202, KCK-242, KCK-249; test frame TF_LEG_04, TF_LEG_05, TF_LEG_08 (KCK-232)

---

## D22 – Messaggi alle entity nei sequence diagram

* **Problema:** I sequence diagram mandano messaggi alle entity (es. `Giocatore.aggiornaDati()` in SD_UC_ACC_1), ma in `class.puml` le entity non hanno metodi e nel codice sono classi di soli dati; l'SDD (§3.2.2, strato Data) affida l'accesso ai dati a un Repository per ogni entity.
* **Decisione:** Ogni messaggio che un sequence manda a un'entity diventa un metodo del **Repository di quella entity**, con lo stesso nome; l'entity resta di soli dati (attributi `final`, `fromJson`/`toJson`). Il Control costruisce l'entity con i nuovi valori e chiama il repository. Messaggi oggi nei sequence:
  * SD_UC_ACC_1: `Account.create(dati)`, `Giocatore.create()`, `Giocatore.aggiornaDati()` → `AccountRepository` (Giocatore e GestoreCampo stanno in AccountRepository);
  * SD_UC_PAR_1: `Campo.getDisponibilita()`, `Campo.getTariffa()` → `CampoRepository`; `Partita.create(stato=Aperta)` → `PartitaRepository`; `Prenotazione.create()` → `PrenotazioneRepository`;
  * SD_UC_PAG_1: `Quota.leggiQuota()`, `Quota.registraVersamento()` → `QuotaRepository`; `Transazione.creaTransazione()` → `TransazioneRepository`.

  Il messaggio di creazione `create` diventa il metodo di inserimento del repository; quando nello stesso repository sarebbe ambiguo (AccountRepository crea sia Account sia Giocatore), il nome si propone nel piano del ticket e si fa approvare.
* **Ticket coinvolti:** KCK-196, KCK-203, KCK-211 (repository); KCK-250, KCK-235, KCK-214 (Control che chiamano questi metodi); KCK-246, KCK-252 (entity)

---

## D23 – Chi genera l'id degli oggetti nuovi

* **Problema:** Nelle entity `id` e' obbligatorio e `toJson` lo scrive, ma nelle migration l'id lo genera il database (`DEFAULT gen_random_uuid()`); va deciso chi lo genera per un oggetto nuovo.
* **Decisione:** L'id lo genera **il database**. Il repository inserisce la riga senza `id`, si fa restituire la riga creata e costruisce l'entity con l'id vero; nelle entity `id` resta obbligatorio (un'entity rappresenta sempre un oggetto salvato) e `toJson` lo scrive per gli aggiornamenti. Nessuna dipendenza nuova per generare uuid nel client. Per Account l'id e' quello di Supabase Auth, scritto dal trigger della migration A. Per la Lega la creazione e' un'unica chiamata (lega, membro e amministratore nella stessa transazione, vedi PR #38) che restituisce l'id.
* **Ticket coinvolti:** KCK-196, KCK-203, KCK-211 (repository); KCK-242 (creazione lega); KCK-246, KCK-252 (entity)

---

## D24 – Valori e vincoli dello schema B (campo, partita, prenotazione, partecipazione)

* **Problema:** RAD e class diagram non elencano i valori di `statoBlocco` e `rispostaStato`, e la regola 4 di `class_diagram_sdd.md` (UNIQUE su campo e intervallo) non impediva slot sovrapposti ma non identici, che il ticket KCK-210 vieta.
* **Decisione:** `Prenotazione.statoBlocco` = `bloccato`, `confermato`, `liberato`; lo slot e' "attivo" quando e' bloccato o confermato, e uno slot bloccato ha sempre `scadenzaBlocco`. `Partecipazione.rispostaStato` = `confermata`, `ritirata`. Gli slot attivi di uno stesso campo non possono sovrapporsi: vincolo di esclusione (`EXCLUDE USING gist`, estensione `btree_gist`) al posto dell'UNIQUE, con intervalli semiaperti (18:00/19:00 e 19:00/20:00 sono ammessi). `Partita.stato` ammette i 5 stati dello statechart (compreso `Confermata`). Una partita pubblica non ha lega (associazione 10): CHECK nel database. D7 si ripete come CHECK (almeno 2 giocatori per lato della tipologia, es. 10 per il 5v5) come seconda difesa: messaggio all'utente, data nel passato, limite di 24 ore (D5) e `gestisciAnnullamento()` (D6) restano nel Control. Importi di `Prenotazione` in `numeric(10,2)`. La FK dell'organizzatore e' `partita.giocatore_id` (regola 9).
* **Cancellazione dei dati (DG4):** le chiavi esterne verso Giocatore, GestoreCampo, Lega, Campo e Partita sono `ON DELETE CASCADE` (D12: la cancellazione dell'account non si blocca mai). Cancellando un organizzatore spariscono le sue partite con prenotazioni e partecipazioni, anche quelle concluse con le statistiche di altri giocatori (DG5): se `CancellazioneAccountControl` deve riassegnarle e' una scelta da fare in KCK-204.
* **Ticket coinvolti:** KCK-210 (migration B, PR #51); KCK-203 (repository B); KCK-252 (entity Partita, Prenotazione, Partecipazione); KCK-204 (cancellazione account)
* **Aggiornamento (23/11/2026, KCK-226):** oltre al Control, i passaggi di stato della partita e il limite di 24 ore per l'annullamento (D5) sono garantiti anche nel database dal trigger `partita_cambio_stato_consentito` (funzione `verifica_cambio_stato_partita()`): dal client e' ammesso solo l'annullamento da parte dell'organizzatore, da Aperta, Completa o Confermata e a piu' di 24 ore da `data_ora`; gli altri passaggi li fa il server. Il messaggio all'utente resta nel Control.

---

## D25 – Quote: chi le crea, importo, commissione e termine di versamento

* **Problema:** Nessun caso d'uso o sequence dice chi crea la Quota e quando, se l'Organizzatore e' un partecipante, come si calcola la quota (UC_PAR_1 passo 3), quanto vale la commissione (RF_PAG_2) e qual e' il termine di versamento (`Quota.termineVersamento`, statechart: scadenza pagamento). Righe C9–C13 di `CONTROLLO_COERENZA.md` (KCK-221).
* **Decisione:**
  * **Organizzatore (C10):** alla creazione della partita viene creata anche la sua Partecipazione con `rispostaStato` = `confermata`: occupa un posto (RF_PAR_2) e versa la quota come gli altri.
  * **Formula (C11):** `costoConcordato` = `Campo.tariffaOraria` × durata in ore di `Prenotazione.intervallo`; `quotaIndividuale` = `costoConcordato` / `Partita.numPartecipantiRichiesti`, arrotondata per eccesso al centesimo; `nettoGestore` = `costoConcordato` − `commissione`.
  * **Commissione (C12):** 5% di `costoConcordato`, arrotondata al centesimo, salvata in `Prenotazione.commissione`; il 5% e' una costante di configurazione definita in un solo punto. Pagamenti solo in modalita' test di Stripe.
  * **Creazione della Quota (C9):** quando la partita passa a Completa, GestionePartitaControl chiede a GestioneTransazioniControl (dipendenza ammessa Partite -> Pagamenti) di creare, tramite QuotaRepository, una Quota per ogni Partecipazione `confermata` che non ne ha gia' una, con `importo` = `quotaIndividuale` e `statoVersamento` = `da_versare`. Valori di `statoVersamento`: `da_versare`, `versata`, `rimborsata`. Se un Giocatore si ritira e la partita torna Aperta, la sua Quota `da_versare` si elimina; se e' `versata` si rimborsa con il flusso di RF_PAG_3.
  * **Termine (C13):** `termineVersamento` = 24 ore prima di `Partita.dataOra` (come D5); se la partita diventa Completa quando mancano gia' meno di 24 ore, 2 ore prima di `dataOra`. Allo scadere con quote `da_versare` il server annulla la partita con il flusso di D6.
* **Ticket coinvolti:** KCK-218 (migration C, CHECK su `statoVersamento`); KCK-211 (repository C); KCK-235 (creazione partita e Partecipazione dell'Organizzatore); KCK-214 (pagamento); KCK-197 (annullamento e rimborsi); KCK-252 (entity Quota, Prenotazione)

---

## D26 – Conferma della partita e chiamate tra sottosistemi

* **Problema:** In SD_UC_PAG_1 la conferma della prenotazione e' un'auto-chiamata di GestioneTransazioniControl, mentre `component.puml` ammette solo Partite -> Pagamenti; in SD_UC_PAR_1 i Control delle Partite leggono il Campo, che sta nel sottosistema Strutture; i messaggi a GatewayPagamenti non hanno operazioni e la notifica di conferma agli altri Giocatori non compare nel sequence. Righe C14, C16, C20, C21 di `CONTROLLO_COERENZA.md` (KCK-221).
* **Decisione:**
  * **Conferma (C14, C15):** GestioneTransazioniControl, tramite QuotaRepository, conta le quote `da_versare` e verifica "tutte le quote versate". Dopo l'ultimo `registraVersamento()` lo rileva il server (trigger o Edge Function, come in D6), che esegue il flusso di `confermaPrenotazione()` di GestionePartitaControl (C4): partita Confermata, slot `confermato` tramite PrenotazioneControl, accredito al Gestore chiesto a GestioneTransazioniControl (`disponiAccredito()`). Non si aggiunge la dipendenza Pagamenti -> Partite.
  * **Campo (C16):** PrenotazioneControl e GestionePartitaControl chiedono disponibilita' e tariffa a GestioneCampiControl (dipendenza ammessa Partite -> Strutture), che usa `CampoRepository` con i metodi di D22. `component.puml` non cambia.
  * **Notifiche (C20):** alla conferma NotificaControl notifica tutti i Giocatori con Partecipazione `confermata` e il Gestore del Campo (estende C7).
  * **GatewayPagamenti (C21):** e' un'interfaccia del livello Data con `richiediPagamento()` e `disponiAccredito()`, piu' il rimborso di RF_PAG_3 da proporre nel piano di KCK-214; `completaPagamento()` lo fa il Giocatore sulla pagina del fornitore e non e' un metodo.
* **Ticket coinvolti:** KCK-214 (pagamento e conferma); KCK-235 (creazione partita); KCK-197 (annullamento); KCK-224, KCK-243 (notifiche); KCK-211 (repository C)

---

## D27 – Valori e vincoli dello schema C (votazione MVP, notifica, quota, transazione)

* **Problema:** RAD e class diagram non elencano i valori di `VotazioneMVP.statoVotazione`, `Notifica.tipo` e `Transazione.stato`; la regola 2 di `class_diagram_sdd.md` chiede un CHECK sui valori ammessi (KCK-218).
* **Decisione:** `statoVotazione` = `aperta` (si apre quando la partita passa a Conclusa, D1), `chiusa` (alla scadenza o a voti completati, con `vincitore` assegnato). `Notifica.tipo` = `apertura_sondaggio_mvp`, `apertura_convocazioni` (RF_NOT_1) e `partita_confermata` (D26, C20); un nuovo tipo si aggiunge con una migration quando un ticket lo richiede. `Transazione.stato` = `in_attesa`, `completata`, `fallita`. `Quota.statoVersamento` resta come in D25. Le tabelle si chiamano `votazione_mvp`, `preferenza_voto_mvp` (la mappa `preferenzeVotanteVotato`, chiave primaria (votazione, votante) e CHECK contro l'autovoto come seconda difesa di D14), `notifica`, `quota`, `transazione`; al massimo un pagamento non fallito per Quota (indice univoco parziale, DG2): un pagamento `fallita` non ha addebitato nulla e il Giocatore puo' riprovare.
* **Ticket coinvolti:** KCK-218 (migration C); KCK-211 (repository C); KCK-252 (entity VotazioneMVP, Notifica, Quota, Transazione)

---

## D28 – Registrazione, ripresa dell'onboarding e regola della password

* **Problema:** Il piano di KCK-250 ha trovato punti non coperti. `AccountRepository` non ha un'operazione per creare le credenziali (registrazione con password) ne' per salvare il ruolo definitivo lasciando la Player Card incompleta; il RAD non dice con quale operazione si riprende l'onboarding interrotto (UC_ACC_1 E3); UC_ACC_1 E2 parla di "password debole" senza dire quando una password e' debole.
* **Decisione:**
  * **Credenziali:** `AccountRepository.registra(email, password, nome, cognome, eta)` crea l'utente nel servizio di autenticazione, con nome, cognome ed eta' nei metadati, e restituisce l'id dell'account: la riga `account` la crea il trigger della Migration A (C6). Se l'email e' gia' registrata (UC_ACC_1 E1) lancia un'`AppException` con codice `email_gia_registrata`, come `credenziali_non_valide` per il login. La password passa solo al servizio di autenticazione e non si salva (`class_diagram_sdd.md` §3, regola 2).
  * **Ruolo definitivo (passo 7):** `AccountRepository.salvaRuolo(accountId, ruolo)` imposta `ruolo_account` e crea la riga `giocatore` con la Player Card vuota (C6: il Giocatore nasce alla scelta del ruolo). `completaOnboardingGiocatore` resta l'operazione che salva la Player Card e porta `statoOnboarding` a `completato`.
  * **Ripresa dell'onboarding (E3):** `RegistrazioneControl.passoOnboardingDaRiprendere(Account)` restituisce `sceltaRuolo` se l'account non ha ancora un ruolo, `playerCard` se e' un Giocatore senza ruolo in campo o piede dominante, `nessuno` se `statoOnboarding` e' `completato`. Il ramo del Gestore del Campo (configurazione della struttura) e' definito dai ticket KCK-223 e KCK-227. Dopo `AutenticazioneControl.login()` la GUI chiama il metodo sull'`Account` restituito.
  * **Password debole (E2):** una password e' valida se ha almeno 8 caratteri, con almeno una lettera e un numero. Altrimenti `PasswordDeboleException` con messaggio "La password deve avere almeno 8 caratteri, una lettera e un numero". La regola sta in una sola funzione del Domain, usata da `RegistrazioneControl` e da `RecuperoPasswordControl` (D16). Il minimo di 6 caratteri di `supabase/config.toml` resta come difesa del servizio.
  * **Chi li scrive:** i due metodi di `AccountRepository` li aggiunge l'autore di KCK-250 nella sua PR (interfaccia, implementazione Supabase e in memoria, test), con Pietro Senatore come revisore: e' un'eccezione alla regola sui repository di altri, decisa dai PM per non fermare lo sprint.
* **Ticket coinvolti:** KCK-250 (registrazione Giocatore e Player Card); KCK-198 (schermate); KCK-234, KCK-262 (recupero password); KCK-223, KCK-227 (ramo Gestore); test frame TF_ACC_01, TF_ACC_04, TF_ACC_18 (KCK-232)

---

## D29 – Formato e durata del codice d'invito della lega

* **Problema:** UC_LEG_1 passo 4 chiede di generare "un codice d'invito univoco" alla creazione della lega e la tabella degli oggetti dice che `Lega` contiene il codice e la sua scadenza, ma il RAD non dice ne' il formato ne' la durata; nel database codice e scadenza sono obbligatori insieme (CHECK `lega_codice_invito_scadenza_check`).
* **Decisione:** Il codice ha 8 caratteri scelti tra lettere maiuscole e cifre, senza quelli facili da confondere (0/O, 1/I), generati con `Random.secure()` di `dart:math` (nessuna dipendenza nuova). La scadenza e' di 7 giorni dalla creazione. Lo genera `GestioneLegaControl`; se il database rifiuta il codice perche' gia' usato, il Control ne genera un altro.
* **Ticket coinvolti:** KCK-242 (creazione lega); KCK-256 (generazione e condivisione dell'invito, adesione)
