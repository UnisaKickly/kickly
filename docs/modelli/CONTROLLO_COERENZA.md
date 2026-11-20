# Controllo di coerenza dei modelli (KCK-221)

Confronto in sola lettura tra casi d'uso, sequence diagram, class diagram e component
diagram, fatto **prima** dei ticket di implementazione. Chi ha fatto il controllo segnala e
non corregge: la colonna "Decisione del team" la compila un PM. Le correzioni ai modelli che
ne derivano si fanno in PR separate.

- **Commit analizzato:** `develop` @ `a36a143` (20/11/2026, dopo il merge di KCK-210)
- **File confrontati:** `docs/rad/uc/*.md`, `docs/modelli/class.puml`,
  `docs/modelli/seq_creazione_partita.puml` (SD_UC_PAR_1), `seq_primo_accesso.puml`
  (SD_UC_ACC_1), `seq_pagamento_quota.puml` (SD_UC_PAG_1), `docs/sdd/component.puml`; per la
  verifica 3 la tabella degli oggetti di `docs/rad/requisiti.md` (§3.4.4.1); per non
  segnalare cose gia' decise `docs/modelli/DECISIONI_RAD.md` (D1–D23), `docs/modelli/class_diagram_sdd.md` e la Migration A
  (`supabase/migrations/20261119122000_schema_a.sql`)

## Metodo

Prompt del ticket: "Confronta docs/modelli/seq_\*.puml con docs/modelli/class.puml e con
docs/rad/uc/\*.md. Elenca: messaggi del sequence senza operazione nel class diagram; passi o
eccezioni del caso d'uso senza messaggi nel sequence; entity del RAD senza classe nel class
diagram. Non modificare nessun file."

Valgono le premesse fissate dai PM il 18/11 (insieme a C1–C8):

- i sequence del RAD sono **3, solo flusso principale** (vincolo della SOW): alternative ed
  errori si prendono dai casi d'uso e dai test frame (C3);
- le entity di riferimento sono quelle dell'SDD §4.2 (`class.puml`); Entity, Control e
  Boundary sono quelli della tabella degli oggetti del RAD (§3.4.4.1);
- i metodi delle classi si formalizzano nell'ODD (KCK-55).

Verifiche fatte:

1. **sequence → class:** ogni messaggio dei 3 sequence ha un'operazione o un attributo nella
   classe destinataria?
2. **caso d'uso → sequence:** ogni passo del flusso principale di UC_ACC_1, UC_PAR_1 e
   UC_PAG_1 ha un messaggio nel sequence? Per UC_LEG_1, UC_MVP_1 e UC_SS_1, che non hanno un
   sequence, il flusso principale e' confrontato con classi e attributi di `class.puml`.
3. **RAD → class:** ogni entity della tabella degli oggetti ha una classe in `class.puml`, e
   viceversa?
4. **sequence → component** (in piu', perche' `component.puml` e' tra le fonti del ticket):
   le chiamate dei sequence rispettano le dipendenze tra sottosistemi di `component.puml`?

Una differenza che rientra in una decisione gia' presa non diventa una riga nuova: e'
elencata in "Differenze gia' coperte". Gravita': **bloccante** = cambia una firma, un nome o
un dato che un Control deve usare; **da chiarire** = manca un valore o una regola;
**minore** = solo testo o documentazione.

## Tabella delle incoerenze

### Gia' decise dai PM (18/11, commento 11105 su KCK-211)

Trovate trascrivendo i sequence (KCK-206). Decisioni riportate come date dai PM.

| Id | Incoerenza | Dove | Gravita' | Decisione del team |
|---|---|---|---|---|
| C1 | Messaggi dei sequence senza operazione nel class diagram | sequence → class | bloccante | `class.puml` (KCK-201) contiene solo le 13 entity dell'SDD §4.2, senza metodi aggiunti. I nomi dei metodi dei Control si prendono dai messaggi dei sequence (es. `RegistrazioneControl.registra(dati)`, `PrenotazioneControl.verificaSlot()/prenotaSlot()`, `GestionePartitaControl.calcolaQuota()`). Per le entity `create()` / `getX()` = costruttore/getter Dart; `Quota.registraVersamento()` e `Transazione.creaTransazione()` si realizzano nei Control/Repository corrispondenti. I metodi delle Boundary non si modellano. |
| C2 | Azioni dello statechart senza classe | statechart → class | bloccante | `confermaPartita()` e `gestisciAnnullamento()` → GestionePartitaControl. `avviaPostPartita()` = apertura della VotazioneMVP → VotoMVPControl, quando la partita passa a Conclusa (decisione D1 di KCK-253). |
| C3 | Nessun frammento `alt` nei sequence | sequence → UC | minore | Corretto cosi' (vincolo SOW): flussi alternativi e di errore si prendono dai casi d'uso (`docs/rad/uc`) e si coprono con i test frame (KCK-232/240/247). |
| C4 | `confermaPrenotazione()` vs `confermaPartita()` | sequence ↔ statechart | bloccante | Un solo metodo nel codice, `confermaPrenotazione()`; il suo effetto e' la transizione Completa → Confermata (nello statechart `confermaPartita`). |
| C5 | `getTariffa()` / `tariffaBase` vs `Campo.tariffaOraria` | sequence → class | bloccante | Vale il class diagram: `tariffaOraria`. |
| C6 | SD_UC_ACC_1 crea Account e poi Giocatore; manca il ramo GestoreCampo | sequence → class | da chiarire | Coerente col DB: Account alla registrazione (trigger Migration A), Giocatore alla scelta del ruolo. Il ramo GestoreCampo e' il flusso A1 di UC_ACC_1 (KCK-223/227). |
| C7 | SD_UC_PAG_1 salta InterfacciaPagamento e NotificaControl | sequence → architettura | da chiarire | Nel codice sempre GUI → Control → Gateway/Repository (DG9); la conferma al Gestore passa da NotificaControl / Edge Function di notifica (KCK-224/243). |
| C8 | `Partita.stato`: manca "Confermata" | class ↔ statechart | bloccante | Valgono tutti gli stati dello statechart (KCK-206): Aperta, Completa, Confermata, Conclusa, Annullata. CHECK della Migration B (KCK-210) e costanti di Partita (KCK-252). |

### Nuove (KCK-221, da decidere)

| Id | Incoerenza | Dove | Gravita' | Decisione del team |
|---|---|---|---|---|
| C9 | **Nessun modello crea la Quota.** UC_PAG_1 parte da un Giocatore "iscritto a una partita nello stato Completa" che "non ha ancora versato la propria quota" (`UC_PAG_1_PagamentoQuota.md:39`) e SD_UC_PAG_1 la legge soltanto (`seq_pagamento_quota.puml:23`, `leggiQuota()`), ma nessun caso d'uso o sequence dice chi crea la Quota (Partecipazione 1 — 0..1 Quota), con quale `importo` e quando: alla risposta RSVP o al passaggio a Completa. | UC → sequence → class | bloccante | da decidere (proposta: la crea GestionePartitaControl per ogni Partecipazione confermata quando la partita passa a Completa, con `importo` = `Prenotazione.quotaIndividuale` e `statoVersamento` iniziale "non versata") |
| C10 | **L'Organizzatore e' anche un partecipante?** SD_UC_PAR_1 crea Partita e Prenotazione ma nessuna Partecipazione (`seq_creazione_partita.puml:33-37`), e UC_PAR_1 non lo dice. Da questo dipendono il conteggio dei posti per Completa (RF_PAR_2) e il fatto che l'Organizzatore paghi una quota (UC_PAG_1). | UC → sequence → class | bloccante | da decidere (proposta: si', alla creazione viene creata la sua Partecipazione con risposta `confermata`; conta nei posti e paga la quota) |
| C11 | **Formula della quota.** UC_PAR_1 passo 3: "dividendo la tariffa base del campo per il numero di partecipanti" (`UC_PAR_1_CreazionePartita.md:69`). Il class diagram ha `Campo.tariffaOraria` (C5) e su Prenotazione `intervallo`, `costoConcordato`, `quotaIndividuale`, `commissione`, `nettoGestore`. Non e' scritto come si ricava `costoConcordato` (tariffa oraria × durata dell'intervallo?), se il divisore e' `numPartecipantiRichiesti`, e se la commissione e' gia' dentro la quota o si aggiunge. | UC → class | bloccante | da decidere (proposta: `costoConcordato` = `tariffaOraria` × ore dell'intervallo; `quotaIndividuale` = `costoConcordato` / `numPartecipantiRichiesti`, arrotondata al centesimo; la commissione si trattiene dal costo, quindi `nettoGestore` = `costoConcordato` − `commissione`) |
| C12 | **Valore della commissione non definito.** RF_PAG_2 e UC_PAG_1 passo 8 parlano di accredito "al netto della commissione trattenuta dalla piattaforma" (`UC_PAG_1_PagamentoQuota.md:74`), ma nessun documento ne da' il valore (percentuale o fissa). | UC → class | da chiarire | da decidere |
| C13 | **Termine di versamento non definito.** `Quota.termineVersamento` (`class.puml:109`) e UC_PAG_1 (passo 2, A3) usano un termine, ma nessun documento dice quanto vale (per esempio N ore prima di `Partita.dataOra`, oppure N ore dal passaggio a Completa). Dal termine dipende anche l'annullamento automatico (statechart: Completa → Annullata per scadenza del pagamento). | UC → class | da chiarire | da decidere (D5 fissa 24 ore solo per l'annullamento dell'Organizzatore) |
| C14 | **Come Pagamenti fa scattare la conferma senza chiamare Partite.** La classe e' gia' decisa: C2 assegna `confermaPartita()` a GestionePartitaControl e C4 dice che e' lo stesso metodo `confermaPrenotazione()`. Pero' in SD_UC_PAG_1 `confermaPrenotazione()` e' un'auto-chiamata di GestioneTransazioniControl (`seq_pagamento_quota.puml:40`), subito dopo il versamento, e `component.puml` ammette solo `PartiteControl ..> PagamentiControl`, non il contrario (`component.puml:89-98`); D6 ribadisce "non si aggiunge la dipendenza inversa". La tabella degli oggetti da' poi a PrenotazioneControl "la conferma e la liberazione dello slot" (`requisiti.md:243`). Non e' scritto come GestioneTransazioniControl, dopo l'ultimo versamento, fa partire `confermaPrenotazione()` di GestionePartitaControl. | sequence → component | bloccante | da decidere (proposta: come per l'annullamento per scadenza in D6, lo rileva il server, con un job o un trigger o Edge Function sull'ultima Quota versata, che chiama il flusso di GestionePartitaControl; GestionePartitaControl usa PrenotazioneControl per lo slot) |
| C15 | **Manca la verifica "tutte le quote versate".** UC_PAG_1 passo 7 (`UC_PAG_1_PagamentoQuota.md:73`) e la guardia dello statechart `[tutte le quote versate]` (`statechart_partita.puml:20`) richiedono un controllo prima della conferma, ma in SD_UC_PAG_1 `confermaPrenotazione()` segue subito il singolo versamento, senza nessun messaggio di verifica. Allo stesso modo i passi 2 e 6 mostrano e aggiornano "il numero di quote ancora mancanti" (`UC_PAG_1_PagamentoQuota.md:68,72`, anche RF_PAG_4), mentre il sequence legge solo la Quota del singolo Giocatore (`leggiQuota()`, riga 23). | UC → sequence | minore | da decidere (proposta: conteggio e verifica stanno in GestioneTransazioniControl tramite QuotaRepository, che "segnala il completamento di tutte le quote" secondo `requisiti.md:270`; il sequence resta com'e', solo flusso principale) |
| C16 | **Accesso diretto al Campo dal sottosistema Partite.** In SD_UC_PAR_1 PrenotazioneControl e GestionePartitaControl leggono Campo (`seq_creazione_partita.puml:21,24`) e D22 manda `getDisponibilita()`/`getTariffa()` a `CampoRepository`. Ma in `component.puml` `CampoRepository` sta nel sottosistema Strutture, e tra sottosistemi diversi sono ammesse solo chiamate tra Control (`PartiteControl ..> StruttureControl`, righe 89-95). | sequence → component | da chiarire | da decidere (proposta: GestionePartitaControl e PrenotazioneControl chiamano GestioneCampiControl, che usa CampoRepository; oppure si ammette la lettura di CampoRepository dalle Partite e lo si scrive in `component.puml`) |
| C17 | **Statistiche "aggiornate" senza attributi.** UC_MVP_1 passo 5 "salva la preferenza e aggiorna i dati statistici dell'utente votato" (`UC_MVP_1_VotoMVP.md:71`), ma Giocatore non ha attributi di statistica: la tabella degli oggetti (`requisiti.md:209`) dice che le statistiche si calcolano con query su Partecipazione e VotazioneMVP. | UC → class | minore | da decidere (proposta: nessun aggiornamento da salvare; "aggiorna" vuol dire che le statistiche calcolate includono subito il nuovo voto) |
| C18 | **"Registra l'azione" senza classe.** UC_SS_1 passo 5 "Registra l'azione e chiude il menù nativo" (`UC_SS_1_CondivisionePartita.md:71`), ma nessuna entity conserva le condivisioni: c'e' solo `Partita.linkCondivisione`. | UC → class | minore | da decidere (proposta: non si salva nulla oltre a `linkCondivisione`; "registra" = chiusura del menu e messaggio "Link copiato!") |
| C19 | **Transazione: date e tipi.** La tabella degli oggetti dice che Transazione registra "pagamento, rimborso o accredito" e "conserva importo, stato, date e riferimento esterno" (`requisiti.md:269`); `class.puml` ha una sola data, `dataEsito` (`class.puml:101`), e il commento della classe dice "un pagamento o un rimborso" (`class.puml:96`), mentre SD_UC_PAG_1 crea anche una Transazione di accredito (`seq_pagamento_quota.puml:43`). | RAD → class | minore | da decidere (proposta: vale il class diagram per gli attributi, con una sola data; i tipi sono tre, pagamento, rimborso e accredito, e il commento di `class.puml` va corretto in una PR separata) |
| C20 | **Notifica di conferma agli altri Giocatori.** UC_PAG_1 passo 8 notifica "ai Giocatori e al Gestore che la partita e' confermata" (`UC_PAG_1_PagamentoQuota.md:74`), ma SD_UC_PAG_1 notifica solo il Gestore (`notificaConferma()`, riga 46) e mostra la conferma solo al Giocatore che paga (righe 44-45). C7 parla solo della conferma al Gestore. | UC → sequence | da chiarire | da decidere (proposta: estendere C7, cioe' NotificaControl notifica tutti i partecipanti confermati e il Gestore) |
| C21 | **Messaggi a GatewayPagamenti.** `richiediPagamento()`, `completaPagamento()` e `disponiAccredito()` (`seq_pagamento_quota.puml:31,32,41`) non hanno un'operazione. C1 dice che i metodi delle Boundary non si modellano, ma GatewayPagamenti, Boundary nel RAD, sta nel livello Data di `component.puml` (riga 69), dove i metodi servono (KCK-211, KCK-214). | sequence → class → component | da chiarire | da decidere (proposta: GatewayPagamenti e' un'interfaccia del livello Data con i metodi presi da questi messaggi, come i repository di D22; `completaPagamento()` e' fatto dal Giocatore sul fornitore e non e' un metodo) |

## Differenze gia' coperte (nessuna riga nuova)

- **C1:** tutti gli altri messaggi senza operazione: `richiediModulo()`, `registra(dati)`,
  `confermaRuolo()`, `salvaPlayerCard()` (RegistrazioneControl); `richiediRiepilogo()`,
  `finalizzaCreazione()`, `verificaSlot()`, `prenotaSlot()` (Partite); `richiediRiepilogo()`,
  `avviaPagamento()` (GestioneTransazioniControl); `aggiornaDati()` su Giocatore. I messaggi
  alle entity sono mappati sui repository da D22. `notificaConferma()`
  verso il Gestore e' coperto da C7. I messaggi a GatewayPagamenti sono in C21.
- **C3:** eccezioni e alternative di tutti i casi d'uso (UC_PAR_1 A1, UC_PAG_1 A1-A3/E1,
  UC_ACC_1 E1-E3/A1, ...) senza messaggi nei sequence.
- **C6, D9, D11:** UC_ACC_1 passo 7 "registra la scelta come definitiva" non ha un messaggio
  che scrive `Account.ruoloAccount` e `statoOnboarding`; valori e ruolo definitivo sono gia'
  decisi da D9 e D11.
- **C7:** il salto di InterfacciaPagamento e NotificaControl in SD_UC_PAG_1 e il percorso
  Control → Gateway/Repository. La notifica agli altri Giocatori e i metodi di
  GatewayPagamenti non sono coperti: sono C20 e C21.
- **Verifica 3:** le 13 entity della tabella degli oggetti (Account, Giocatore, GestoreCampo,
  DispositivoRegistrato, Lega, Partita, Campo, Prenotazione, Partecipazione, VotazioneMVP,
  Notifica, Quota, Transazione) hanno tutte una classe in `class.puml`, e `class.puml` non ha
  classi in piu'. Le uniche differenze di attributi e di testo sono in C19.
- **UC_LEG_1:** "5vs5" e "Pubblica/Privata" dei casi d'uso contro `5v5` e
  `pubblica`/`privata` del DB: e' gia' risolto nel commento di `lega.tipologia_match` della
  Migration A (la conversione la fa il codice Dart).

## Verifica a campione (3 righe ricontrollate a mano)

1. **C9.** `seq_pagamento_quota.puml` ha 4 messaggi verso Quota/Transazione (righe 23, 34, 35,
   43): nessuno e' una creazione di Quota. `seq_creazione_partita.puml` crea solo Partita e
   Prenotazione (righe 33-37). `grep -n "Quota" docs/rad/uc/*.md` non trova nessun passo che la
   crea, e in `DECISIONI_RAD.md` nessuna decisione ne parla. **Confermata.**
2. **C14.** Riga 40 di `seq_pagamento_quota.puml`:
   `GestioneTransazioniControl -> GestioneTransazioniControl : confermaPrenotazione()`.
   `component.puml` righe 89-98: tra i Control ci sono `PartiteControl ..> PagamentiControl`
   e `PagamentiControl ..> VotoNotificheControl`, nessun `PagamentiControl ..> PartiteControl`.
   **Confermata.**
3. **C16.** `seq_creazione_partita.puml` righe 21 e 24 chiamano `Campo` da PrenotazioneControl
   e GestionePartitaControl; D22 (`DECISIONI_RAD.md:190`) li manda a `CampoRepository`;
   `component.puml` riga 59 mette `CampoRepository` nel package "parte Strutture". **Confermata.**

Escluso come falso positivo: "SD_UC_ACC_1 non salva la password". Non e' un'incoerenza, perche'
`Account.password` e' realizzata da Supabase Auth (regola 2 di `class_diagram_sdd.md`).
