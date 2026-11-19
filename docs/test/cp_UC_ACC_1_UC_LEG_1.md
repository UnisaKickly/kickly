# Category partition - UC_ACC_1 Registrazione e Onboarding e UC_LEG_1 Creazione Lega e Invito Membri

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/UC_ACC_1_RegistrazioneOnboarding.md`, `docs/rad/uc/UC_LEG_1_CreazioneLegaEInvito.md` |
| **Requisiti** | RF_ACC_1, RF_ACC_2, RF_ACC_3, RF_ACC_4, RF_LEG_1, RF_LEG_2, RF_LEG_3, RF_LEG_4 |
| **Metodo testato** | Una funzione per sezione (vedi §1). Registrazione e onboarding: `RegistrazioneControl.richiediModulo`, `RegistrazioneControl.registra`, `RegistrazioneControl.confermaRuolo`, `RegistrazioneControl.salvaPlayerCard` (SD_UC_ACC_1). Per `AutenticazioneControl`, `RecuperoPasswordControl`, `GestioneLegaControl` e `GestioneAdesioneControl` il RAD non definisce le firme: i metodi si propongono nel piano dei ticket che implementano i Control |
| **Autori** | Giuseppe Sarlo |
| **Revisori** | Mario Celzo, Renato Mancino |

Metodo: category partition (Ostrand e Balcer, 1988). Il sistema e' diviso in
funzioni testabili in modo indipendente (F1-F11, sezione 1); per ogni funzione
si individuano parametri e condizioni dell'ambiente, categorie, scelte (valori
normali, limite, speciali e di errore) e vincoli. Un test frame e' una
combinazione valida con **una scelta per ogni categoria della stessa
funzione**: le categorie di funzioni diverse non si combinano. Una scelta
`[error]` o `[single]` produce un solo frame e non si combina con le altre.

Fonti degli esiti attesi: i casi d'uso UC_ACC_1 e UC_LEG_1, RAD v2.9 §3.2
(RF_ACC_1..4, RF_LEG_1..4), la tabella degli oggetti (§3.4.4.1.1 e
§3.4.4.1.2), il sequence SD_UC_ACC_1 (`docs/modelli/seq_primo_accesso.puml`) e
`docs/modelli/DECISIONI_RAD.md` (D9, D11). Dove nessuna fonte dice l'esito, il
frame e' marcato **DA CONFERMARE** e rimanda a una domanda della sezione 4:
l'esito non e' stato ipotizzato.

Fuori dai frame: RNF_U_1 (DG6, onboarding in meno di 3 minuti) e RNF_U_2 (DG7,
adesione a una lega in al massimo 3 interazioni) sono soglie di usabilita': non
sono scelte di un parametro o dell'ambiente e si misurano a parte. L'accesso da
un dispositivo nuovo (RF_SS_2) e' in `cp_UC_MVP_1_UC_SS_1.md`.

## 1. Funzioni, parametri e condizioni dell'ambiente

| Funzione | Control | Requisiti | Parametri | Condizioni dell'ambiente |
|---|---|---|---|---|
| F1 Registrazione | `RegistrazioneControl` | UC_ACC_1 passi 1-5, E1, E2 | nome, cognome, email, password, eta' | email gia' registrata o no |
| F2 Onboarding | `RegistrazioneControl` | UC_ACC_1 passi 5-9, A1, E3; RF_ACC_1, RF_ACC_2; D9, D11 | ruolo scelto; ruolo in campo e piede dominante | completamento o interruzione dell'onboarding |
| F3 Login | `AutenticazioneControl` | RF_ACC_3 | email, password | account registrato o no |
| F4 Logout | `AutenticazioneControl` (da `ImpostazioniAccount`) | RF_ACC_3 | nessuno | sessione autenticata |
| F5 Recupero password | `RecuperoPasswordControl` | RF_ACC_4 | email; nuova password | email associata a un account o no; collegamento di verifica |
| F6 Creazione lega | `GestioneLegaControl` | UC_LEG_1 passi 1-4, E1, A1; RF_LEG_1 | nome, tipologia, privacy | nome gia' in uso o no |
| F7 Modifica dei dettagli della lega | `GestioneLegaControl` | RF_LEG_1 | nome, tipologia, privacy | ruolo dell'utente nella lega |
| F8 Generazione e condivisione dell'invito | `GestioneLegaControl` | UC_LEG_1 passi 4-5; RF_LEG_2 | canale (codice o link) | ruolo dell'utente nella lega |
| F9 Adesione alla lega | `GestioneAdesioneControl` | UC_LEG_1 passi 6-7, E2, A1; RF_LEG_2 | modalita' di adesione; codice o link | privacy della lega; validita' dell'invito; Giocatore gia' membro o no |
| F10 Gestione membri | `GestioneLegaControl` | RF_LEG_3 | operazione; membro su cui agire | ruolo dell'utente nella lega |
| F11 Dashboard della lega | `GestioneLegaControl` | RF_LEG_4 | nessuno (consultazione) | appartenenza del Giocatore alla lega |

## 2. Categorie e scelte

Vincoli: `[error]` scelta che porta a un errore o a un'operazione rifiutata (un
solo frame); `[single]` caso speciale o limite da provare una sola volta;
`[property X]` / `[if X]` solo dove servono a escludere combinazioni
contraddittorie.

### F1 Registrazione

| Categoria | Scelta | Vincolo |
|---|---|---|
| Email | non registrata | |
| Email | gia' registrata (E1) | `[error]` |
| Campi obbligatori | tutti presenti | |
| Campi obbligatori | almeno uno mancante (E2) | `[error]` |
| Password | conforme | |
| Password | debole (E2) | `[error]` |

### F2 Onboarding

| Categoria | Scelta | Vincolo |
|---|---|---|
| Ruolo scelto | Giocatore | `[property Giocatore]` |
| Ruolo scelto | Gestore del Campo (A1) | `[property Gestore]` |
| Player Card | ruolo in campo e piede dominante inseriti | `[if Giocatore]` |
| Player Card | non prevista | `[if Gestore]` |
| Player Card | ruolo in campo o piede dominante mancante (Giocatore) | `[error]` |
| Completamento | onboarding completato | |
| Completamento | interrotto dopo la registrazione, prima della scelta del ruolo (E3) | `[single]` |
| Completamento | interrotto prima del salvataggio della Player Card (E3) | `[single]` |

### F3 Login

| Categoria | Scelta | Vincolo |
|---|---|---|
| Email | di un account registrato | |
| Email | non registrata | `[error]` |
| Password | corretta | |
| Password | errata | `[error]` |
| Compilazione | email e password inserite | |
| Compilazione | email o password vuota | `[error]` |

### F4 Logout

| Categoria | Scelta | Vincolo |
|---|---|---|
| Sessione | autenticata | |

Una sola scelta per la categoria: il metodo lo ammette (slide "Scelte").

### F5 Recupero password

| Categoria | Scelta | Vincolo |
|---|---|---|
| Email inserita | associata a un account | |
| Email inserita | non associata ad alcun account | `[error]` |
| Collegamento di verifica | valido | |
| Collegamento di verifica | scaduto o non valido | `[error]` |
| Nuova password | conforme | |
| Nuova password | debole | `[error]` |

### F6 Creazione lega

| Categoria | Scelta | Vincolo |
|---|---|---|
| Nome | presente e non in uso | |
| Nome | gia' in uso (E1) | `[error]` |
| Nome | vuoto (E1, dati non validi) | `[error]` |
| Tipologia | 5vs5 (valore limite inferiore) | |
| Tipologia | 11vs11 (valore limite superiore) | `[single]` |
| Privacy | Privata | |
| Privacy | Pubblica (A1) | |

### F7 Modifica dei dettagli della lega

| Categoria | Scelta | Vincolo |
|---|---|---|
| Ruolo dell'utente | amministratore della lega | |
| Ruolo dell'utente | membro non amministratore | `[error]` |
| Nuovi dati | validi | |
| Nuovi dati | nome gia' in uso da un'altra lega | `[error]` |

### F8 Generazione e condivisione dell'invito

| Categoria | Scelta | Vincolo |
|---|---|---|
| Ruolo dell'utente | amministratore della lega | |
| Ruolo dell'utente | membro non amministratore | `[error]` |
| Canale | codice d'invito | |
| Canale | link d'invito | |

### F9 Adesione alla lega

| Categoria | Scelta | Vincolo |
|---|---|---|
| Privacy della lega | Privata | |
| Privacy della lega | Pubblica | `[property Pubblica]` |
| Modalita' di adesione | codice inserito a mano | `[property ConInvito]` |
| Modalita' di adesione | link d'invito | `[property ConInvito] [single]` |
| Modalita' di adesione | accesso diretto (A1) | `[if Pubblica]` |
| Invito | valido | `[if ConInvito]` |
| Invito | nessuno (accesso diretto) | `[if not ConInvito]` |
| Invito | errato, nessuna lega associata (E2) | `[error]` |
| Invito | scaduto (E2) | `[error]` |
| Stato del Giocatore | non ancora membro | |
| Stato del Giocatore | gia' membro della lega | `[single]` |

### F10 Gestione membri

| Categoria | Scelta | Vincolo |
|---|---|---|
| Ruolo dell'utente | amministratore della lega | |
| Ruolo dell'utente | membro non amministratore | `[error]` |
| Operazione | visualizza la lista dei membri | |
| Operazione | promuove un membro ad amministratore | `[property Modifica]` |
| Operazione | rimuove un membro dalla lega | `[property Modifica]` |
| Membro su cui agire | nessuno (sola consultazione) | `[if not Modifica]` |
| Membro su cui agire | un membro ordinario | `[if Modifica]` |
| Membro su cui agire | se stesso, unico amministratore della lega (valore limite) | `[single]` |

### F11 Dashboard della lega

| Categoria | Scelta | Vincolo |
|---|---|---|
| Appartenenza | membro della lega | |
| Appartenenza | non membro | `[error]` |

## 3. Test frame

L'esito atteso si prende dal caso d'uso, dagli RF, dalla tabella degli oggetti
e dalle decisioni dei PM, mai dal comportamento del codice. Ogni frame avra' un
test con l'id in minuscolo nel nome (es. `tf_acc_01_...`) nel ticket che
implementa il Control corrispondente.

### 3.1 F1 Registrazione (UC_ACC_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_01 | email non registrata, campi presenti, password conforme | Utente non registrato nella schermata iniziale | L'account viene creato (statoAccount `attivo`, statoOnboarding `in_corso`) e il sistema avvia l'onboarding chiedendo di scegliere il ruolo | UC_ACC_1 passi 1-5, D9 |
| TF_ACC_02 | email gia' registrata | Esiste gia' un account con la stessa email | Il sistema mostra un errore e propone login o email diversa; l'account non viene creato e si riprende dal passo 3 | UC_ACC_1 E1 |
| TF_ACC_03 | campo obbligatorio mancante | Modulo senza uno dei campi (es. eta') | Il sistema mostra l'errore specifico; l'account non viene creato e si riprende dal passo 3 | UC_ACC_1 E2 |
| TF_ACC_04 | password debole | Modulo completo con password debole | Il sistema mostra l'errore specifico; l'account non viene creato e si riprende dal passo 3 | UC_ACC_1 E2 |

### 3.2 F2 Onboarding (UC_ACC_1, RF_ACC_1, RF_ACC_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_05 | Giocatore, Player Card inserita, completato | Account appena creato, onboarding avviato | Il ruolo Giocatore e' registrato come definitivo; la Player Card e' salvata; il sistema mostra la dashboard con le statistiche iniziali azzerate; statoOnboarding `completato` | UC_ACC_1 passi 6-9, RF_ACC_2, D9, D11 |
| TF_ACC_06 | Gestore del Campo, Player Card non prevista, completato | Account appena creato, onboarding avviato | Il ruolo Gestore del Campo e' registrato come definitivo e l'utente e' reindirizzato alla configurazione della propria struttura sportiva, al posto dei passi 7-9 | UC_ACC_1 A1, RF_ACC_1, D11 |
| TF_ACC_07 | Player Card con ruolo in campo o piede dominante mancante | Giocatore nella configurazione della Player Card | **DA CONFERMARE** (domanda 1): il RAD non dice cosa succede se si conferma la Player Card incompleta | UC_ACC_1 passo 8 |
| TF_ACC_08 | onboarding interrotto prima della scelta del ruolo | L'utente esce dopo la creazione dell'account senza scegliere il ruolo | L'account resta con onboarding incompleto (statoOnboarding `in_corso`); al successivo accesso il sistema ripropone la scelta del ruolo | UC_ACC_1 E3, exit condition on failure, D9 |
| TF_ACC_09 | onboarding interrotto prima del salvataggio della Player Card | Giocatore che esce dalla configurazione della Player Card senza confermare | L'onboarding resta incompleto; al successivo accesso il sistema ripropone la configurazione della Player Card | UC_ACC_1 E3, exit condition on failure, D9 |

### 3.3 F3 Login (RF_ACC_3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_10 | email registrata, password corretta, campi inseriti | Account registrato con onboarding completato | L'utente accede al proprio account e il sistema mostra la Dashboard | RF_ACC_3, tabella degli oggetti (`FormLogin`, `Dashboard`) |
| TF_ACC_11 | email non registrata | Nessun account con l'email inserita | L'utente non viene autenticato. Messaggio mostrato: **DA CONFERMARE** (domanda 2) | RF_ACC_3 |
| TF_ACC_12 | password errata | Account registrato, password sbagliata | L'utente non viene autenticato. Messaggio mostrato: **DA CONFERMARE** (domanda 2) | RF_ACC_3 |
| TF_ACC_13 | email o password vuota | Modulo di login incompleto | L'utente non viene autenticato. Messaggio mostrato: **DA CONFERMARE** (domanda 2) | RF_ACC_3 |

### 3.4 F4 Logout (RF_ACC_3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_14 | sessione autenticata | Utente autenticato che sceglie il logout da `ImpostazioniAccount` | La sessione viene chiusa: per accedere di nuovo servono le credenziali | RF_ACC_3, tabella degli oggetti (`ImpostazioniAccount`) |

### 3.5 F5 Recupero password (RF_ACC_4)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_15 | email associata, collegamento valido, nuova password conforme | Account registrato che ha dimenticato la password | Il sistema invia l'email di verifica tramite `ServizioEmail`; dopo la verifica la nuova password e' impostata e l'utente accede con quella | RF_ACC_4, tabella degli oggetti (`RecuperoPasswordControl`, `ServizioEmail`) |
| TF_ACC_16 | email non associata ad alcun account | Nessun account con l'email inserita | **DA CONFERMARE** (domanda 3) | RF_ACC_4 |
| TF_ACC_17 | collegamento scaduto o non valido | Collegamento di verifica gia' usato o scaduto | La password non viene cambiata. Cosa vede l'utente: **DA CONFERMARE** (domanda 4) | RF_ACC_4 |
| TF_ACC_18 | nuova password debole | Collegamento valido, nuova password debole | La password non viene cambiata. Messaggio mostrato: **DA CONFERMARE** (domanda 5) | RF_ACC_4 |

### 3.6 F6 Creazione lega (UC_LEG_1, RF_LEG_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_01 | nome non in uso, 5vs5, Privata | Giocatore autenticato nella sezione "Leghe" | La lega e' registrata, l'utente ne diventa Amministratore, viene generato un codice d'invito univoco e viene mostrata la dashboard della lega | UC_LEG_1 passi 1-4 |
| TF_LEG_02 | nome non in uso, 5vs5, Pubblica | Giocatore autenticato nella sezione "Leghe" | Come TF_LEG_01; inoltre la lega e' visibile nella ricerca globale e consente l'accesso diretto anche senza codice d'invito | UC_LEG_1 passi 1-4, A1 |
| TF_LEG_03 | tipologia 11vs11 | Giocatore autenticato nella sezione "Leghe" | La lega e' registrata con tipologia 11vs11 e l'utente ne diventa Amministratore | UC_LEG_1 passi 1-4, RF_LEG_1 |
| TF_LEG_04 | nome gia' in uso | Esiste gia' una lega con lo stesso nome | Il sistema mostra un messaggio di errore ed evidenzia i campi da correggere, rimanendo al passo 2; la lega non viene creata | UC_LEG_1 E1 |
| TF_LEG_05 | nome vuoto | Modulo di creazione senza nome | Il sistema mostra un messaggio di errore ed evidenzia i campi da correggere, rimanendo al passo 2; la lega non viene creata | UC_LEG_1 E1 |

### 3.7 F7 Modifica dei dettagli della lega (RF_LEG_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_06 | amministratore, dati validi | Amministratore che modifica nome, tipologia o privacy in `FormLega` | I dettagli della lega sono aggiornati e la dashboard mostra i nuovi dati | RF_LEG_1, tabella degli oggetti (`FormLega`) |
| TF_LEG_07 | membro non amministratore | Membro ordinario della lega | **DA CONFERMARE** (domanda 6): la modifica e' riservata all'amministratore, ma il RAD non dice cosa vede il membro | RF_LEG_1 |
| TF_LEG_08 | nome gia' in uso da un'altra lega | Amministratore che rinomina la lega con il nome di un'altra | **DA CONFERMARE** (domanda 7): E1 di UC_LEG_1 vale per la creazione; per la modifica il RAD non lo dice | RF_LEG_1 |

### 3.8 F8 Generazione e condivisione dell'invito (UC_LEG_1, RF_LEG_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_09 | amministratore, codice d'invito | Lega appena creata | Selezionando "Condividi Invito" l'amministratore invia il codice univoco generato a un altro Giocatore | UC_LEG_1 passi 4-5, RF_LEG_2 |
| TF_LEG_10 | amministratore, link d'invito | Lega esistente | L'amministratore genera e condivide il link d'invito della lega | RF_LEG_2 |
| TF_LEG_11 | membro non amministratore | Membro ordinario della lega | **DA CONFERMARE** (domanda 6): generare e condividere l'invito e' dell'amministratore (RF_LEG_2), ma il RAD non dice cosa vede il membro | RF_LEG_2 |

### 3.9 F9 Adesione alla lega (UC_LEG_1, RF_LEG_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_12 | Privata, codice a mano, invito valido, non membro | Secondo Giocatore autenticato nella sezione "Leghe" con il codice ricevuto | Il sistema verifica il codice, aggiunge il Giocatore all'elenco dei membri e aggiorna la dashboard della lega | UC_LEG_1 passi 6-7 |
| TF_LEG_13 | Pubblica, codice a mano, invito valido, non membro | Come TF_LEG_12, lega pubblica | Il sistema verifica il codice, aggiunge il Giocatore all'elenco dei membri e aggiorna la dashboard della lega | UC_LEG_1 passi 6-7 |
| TF_LEG_14 | Pubblica, accesso diretto, nessun invito, non membro | Giocatore che trova la lega pubblica nella ricerca | Il Giocatore accede direttamente alla lega senza codice d'invito | UC_LEG_1 A1 |
| TF_LEG_15 | link d'invito | Giocatore che apre il link d'invito ricevuto | Il Giocatore si unisce alla lega tramite il link | RF_LEG_2 |
| TF_LEG_16 | Giocatore gia' membro | Il Giocatore inserisce il codice di una lega di cui e' gia' membro | **DA CONFERMARE** (domanda 8) | UC_LEG_1 passi 6-7 |
| TF_LEG_17 | invito errato | Codice non associato ad alcuna lega | Il sistema non trova alcuna lega associata, notifica l'errore richiedendo un nuovo inserimento e interrompe la procedura di unione | UC_LEG_1 E2 |
| TF_LEG_18 | invito scaduto | Codice di una lega esistente ma scaduto | Come E2: il sistema notifica l'errore richiedendo un nuovo inserimento e interrompe la procedura di unione; il Giocatore non viene aggiunto | UC_LEG_1 E2 ("codice errato o scaduto") |

### 3.10 F10 Gestione membri (RF_LEG_3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_19 | amministratore, visualizza la lista | Lega con piu' membri | L'amministratore visualizza la lista dei membri | RF_LEG_3 |
| TF_LEG_20 | amministratore, promuove un membro ordinario | Lega con almeno un membro ordinario | Il membro diventa amministratore della lega e resta tra i membri | RF_LEG_3 |
| TF_LEG_21 | amministratore, rimuove un membro ordinario | Lega con almeno un membro ordinario | Il membro e' rimosso dalla lega e la lista dei membri e' aggiornata | RF_LEG_3 |
| TF_LEG_22 | unico amministratore che rimuove se stesso | L'utente e' l'unico amministratore della lega | **DA CONFERMARE** (domanda 9): il class diagram prevede almeno un amministratore per lega, ma il RAD non dice l'esito | RF_LEG_3, class diagram (1..* amministratori) |
| TF_LEG_23 | membro non amministratore | Membro ordinario che prova a promuovere o rimuovere | **DA CONFERMARE** (domanda 6): operazioni riservate all'amministratore (RF_LEG_3), ma il RAD non dice cosa vede il membro | RF_LEG_3 |

### 3.11 F11 Dashboard della lega (RF_LEG_4)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_24 | membro della lega | Giocatore membro che apre la lega | La dashboard mostra informazioni generali, lista dei partecipanti, prossime partite, storico degli incontri e classifica con le statistiche dei giocatori (gol e assist) | RF_LEG_4, tabella degli oggetti (`DashboardLega`) |
| TF_LEG_25 | non membro | Giocatore che non appartiene alla lega prova ad aprirne la dashboard | **DA CONFERMARE** (domanda 10) | RF_LEG_4 |

Totale frame: 43 (TF_ACC_01..18, TF_LEG_01..25)

Copertura: UC_ACC_1 E1 -> TF_ACC_02, E2 -> TF_ACC_03 e TF_ACC_04, E3 ->
TF_ACC_08 e TF_ACC_09, A1 -> TF_ACC_06; UC_LEG_1 E1 -> TF_LEG_04 e TF_LEG_05,
E2 -> TF_LEG_17 e TF_LEG_18, A1 -> TF_LEG_02 e TF_LEG_14. Scelte al confine
richieste dal ticket: nome lega duplicato (TF_LEG_04), codice scaduto
(TF_LEG_18).

## 4. Domande aperte per i PM

Finche' non ci sono risposte, i frame marcati **DA CONFERMARE** non hanno un
esito completo e non vanno implementati come test.

1. TF_ACC_07: cosa succede se il Giocatore conferma la Player Card senza ruolo in campo o piede dominante?
2. TF_ACC_11-13: messaggio per il login fallito. Stesso messaggio generico per email non registrata e password errata (cosi' non si rivela quali email sono registrate)? E per i campi vuoti?
3. TF_ACC_16: cosa vede chi chiede il recupero con un'email non associata (messaggio generico, per lo stesso motivo)?
4. TF_ACC_17: cosa vede chi usa un collegamento di recupero scaduto o non valido (nuova richiesta?).
5. TF_ACC_18: nuova password debole nel recupero: stesso controllo e messaggio di UC_ACC_1 E2?
6. TF_LEG_07, TF_LEG_11, TF_LEG_23: un membro non amministratore che prova un'operazione riservata vede il comando nascosto o riceve un errore?
7. TF_LEG_08: rinominare la lega con un nome gia' in uso si comporta come E1 della creazione?
8. TF_LEG_16: cosa succede se un membro usa di nuovo il codice della sua lega?
9. TF_LEG_22: l'unico amministratore puo' rimuovere se stesso? Se no, con quale messaggio; se si', cosa succede alla lega (vedi anche D12)?
10. TF_LEG_25: cosa vede un non membro che apre la dashboard di una lega (privata o pubblica)?
