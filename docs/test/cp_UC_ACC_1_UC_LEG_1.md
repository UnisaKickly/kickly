# Category partition - UC_ACC_1 Registrazione e Onboarding e UC_LEG_1 Creazione Lega e Invito Membri

| | |
|---|---|
| **Casi d'uso** | `docs/rad/uc/UC_ACC_1_RegistrazioneOnboarding.md`, `docs/rad/uc/UC_LEG_1_CreazioneLegaEInvito.md` |
| **Requisiti** | RF_ACC_1, RF_ACC_2, RF_ACC_3, RF_ACC_4, RF_LEG_1, RF_LEG_2, RF_LEG_3, RF_LEG_4 |
| **Metodo testato** | Registrazione e onboarding: `RegistrazioneControl.richiediModulo()`, `RegistrazioneControl.registra(dati)`, `RegistrazioneControl.avviaOnboarding()`, `RegistrazioneControl.confermaRuolo()`, `RegistrazioneControl.mostraConfigurazione()`, `RegistrazioneControl.salvaPlayerCard()`; autenticazione e recupero: `AutenticazioneControl`, `RecuperoPasswordControl`, `ImpostazioniAccount`, `ServizioEmail`; leghe e inviti: `GestioneLegaControl`, `GestioneAdesioneControl`. Nel RAD e nei model non sono presenti altre firme di metodi per autenticazione, recupero password e gestione leghe. |
| **Autori** | Copilot |
| **Revisori** | Da indicare |

Fonti degli esiti attesi: i due casi d'uso sopra, RAD v2.9 §3.2
(RF_ACC_1..4 e RF_LEG_1..4) e §3.4 (modello di sistema), e
`docs/test/README.md`. Gli esiti non sono dedotti dal comportamento del codice.
In particolare, i frame `TF_ACC_07..13` derivano da RF_ACC_3 e RF_ACC_4 della
sezione 3.2 del RAD v2.9 e i frame `TF_LEG_13..18` derivano da RF_LEG_3 e
RF_LEG_4 della sezione 3.2 del RAD v2.9, oltre alla tabella degli oggetti della
sezione 3.4.

## 1. Parametri e condizioni dell'ambiente

| Parametro / condizione | Descrizione |
|---|---|
| Dati di registrazione | nome, cognome, email, password ed eta per la creazione dell'Account |
| Unicita' email | email gia' registrata oppure libera |
| Completezza e validita' dati | campi registrazione presenti e dati validi, oppure mancanti/password debole |
| Ruolo account | Giocatore o Gestore del Campo |
| Stato onboarding | completo, interrotto prima della scelta del ruolo, o interrotto durante la Player Card |
| Dati Player Card | ruolo preferito in campo e piede dominante |
| Credenziali login | email e password dell'account |
| Stato autenticazione | account esistente oppure credenziali errate |
| Logout | sessione attiva e richiesta dell'utente |
| Email di recupero | email associata a un Account oppure non registrata |
| Nuova password | conforme o debole |
| Token o collegamento di recupero | valido oppure scaduto/non valido |
| Nome della lega | presente, valido e non gia' in uso, oppure duplicato |
| Tipologia match | uno dei formati ammessi: 5vs5, 6vs6, 7vs7, 8vs8, 9vs9, 10vs10, 11vs11 |
| Privacy lega | Pubblica o Privata |
| Stato creazione lega | dati validi oppure dati non validi |
| Codice invito | esistente, corrispondente alla lega e non scaduto, errato oppure scaduto |
| Modalita' di adesione | codice manuale, link valido o accesso diretto a lega pubblica |
| Stato adesione | Giocatore non ancora membro oppure gia' membro |
| Permesso amministratore | utente amministratore della lega oppure membro senza permesso |
| Operazione sui membri | promuove ad amministratore oppure rimuove dalla lega |
| Appartenenza alla dashboard | Giocatore membro della lega oppure non membro |

## 2. Categorie e scelte

### Dati di registrazione e unicita' email

| Categoria | Scelta | Vincolo |
|---|---|---|
| Email | libera | `[property EmailLibera]` |
| Email | gia' registrata | `[error]` |
| Completezza | tutti i dati presenti e validi | `[if EmailLibera] [property DatiValidi]` |
| Completezza | campo mancante o password debole | `[error]` |

### Ruolo account e onboarding

| Categoria | Scelta | Vincolo |
|---|---|---|
| Ruolo | Giocatore | `[if DatiValidi] [property Giocatore]` |
| Ruolo | Gestore del Campo | `[if DatiValidi] [property GestoreCampo] [single]` |
| Stato | onboarding completato | |
| Stato | interrotto prima della scelta ruolo | `[error] [single]` |
| Stato | interrotto durante la configurazione Player Card | `[error] [single]` |

### Dati Player Card

| Categoria | Scelta | Vincolo |
|---|---|---|
| Configurazione | ruolo preferito e piede dominante presenti | `[if Giocatore] [property PlayerCardCompleta]` |
| Configurazione | dati Player Card mancanti | `[error] [if Giocatore]` |

### Login e logout

| Categoria | Scelta | Vincolo |
|---|---|---|
| Credenziali | email e password corrette | `[property LoginValido]` |
| Credenziali | email o password errate | `[error]` |
| Campi login | presenti | `[if LoginValido]` |
| Campi login | mancanti | `[error]` |
| Sessione | logout richiesto da sessione autenticata | `[single] [property LogoutValido]` |

### Recupero password

| Categoria | Scelta | Vincolo |
|---|---|---|
| Email di recupero | associata a Account esistente | `[property EmailRecuperoEsistente]` |
| Email di recupero | non registrata | `[error]` |
| Collegamento | valido | `[if EmailRecuperoEsistente] [property RecuperoValido]` |
| Collegamento | scaduto o non valido | `[error] [single]` |
| Nuova password | conforme | `[if RecuperoValido] [property PasswordNuovaValida]` |
| Nuova password | debole o non conforme | `[error] [single]` |

### Nome, formato e privacy della lega

| Categoria | Scelta | Vincolo |
|---|---|---|
| Nome | presente e unico | `[property NomeLegaValido]` |
| Nome | duplicato | `[error] [single]` |
| Nome | vuoto o non valido | `[error] [single]` |
| Tipologia match | 5vs5 | |
| Tipologia match | una delle altre tipologie 6vs6..11vs11 | `[property TipologiaValida]` |
| Tipologia match | valore non ammesso | `[error] [single]` |
| Privacy | Privata | `[property LegaPrivata]` |
| Privacy | Pubblica | `[property LegaPubblica] [single]` |

### Codice invito e modalita' di adesione

| Categoria | Scelta | Vincolo |
|---|---|---|
| Codice | valido e non scaduto | `[property InvitoValido]` |
| Codice | errato o non associato a una lega | `[error] [single]` |
| Codice | scaduto | `[error] [single]` |
| Modalita' | inserimento manuale del codice | `[if InvitoValido]` |
| Modalita' | accesso tramite link valido | `[if InvitoValido] [single]` |
| Modalita' | accesso diretto a lega pubblica | `[if LegaPubblica] [property AccessoPubblico] [single]` |

### Gestione membri e dashboard

| Categoria | Scelta | Vincolo |
|---|---|---|
| Permesso | Amministratore della lega | `[property PermessoAmministratore]` |
| Permesso | membro senza permesso | `[error] [single]` |
| Operazione | promuove membro ad amministratore | `[if PermessoAmministratore] [property Promozione]` |
| Operazione | rimuove membro | `[if PermessoAmministratore] [property Rimozione]` |
| Appartenenza | membro della lega | `[property MembroLega] [property AccessoDashboard]` |
| Appartenenza | non membro della lega | `[error] [single]` |

## 3. Test frame

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_ACC_01 | Email libera; dati validi; ruolo Giocatore; Player Card completa | Utente non registrato senza account con la stessa email | L'Account viene creato, il ruolo viene registrato in modo definitivo, la Player Card viene salvata e viene mostrata la dashboard con le statistiche iniziali azzerate | UC_ACC_1 flusso principale, passi 1-9 |
| TF_ACC_02 | Email libera; dati validi; ruolo Gestore del Campo | Utente non registrato | L'Account viene creato, il ruolo Gestore del Campo viene registrato in modo definitivo e l'utente viene indirizzato alla configurazione della propria struttura sportiva | UC_ACC_1 A1; RF_ACC_1 |
| TF_ACC_03 | Email gia' registrata | Esiste un Account con la stessa email | Il sistema mostra l'errore relativo all'email gia' registrata e propone login o email diversa; l'Account non viene creato e si riprende dal passo 3 | UC_ACC_1 E1 |
| TF_ACC_04 | Campo mancante o password debole | Modulo di registrazione compilato parzialmente o con password debole | Il sistema mostra l'errore specifico sui dati non validi; l'Account non viene creato e si resta sul modulo per correggere i dati | UC_ACC_1 E2 |
| TF_ACC_05 | Onboarding interrotto prima della scelta del ruolo | Registrazione completata ma ruolo non scelto | Al successivo accesso il sistema ripropone la scelta del ruolo | UC_ACC_1 E3 |
| TF_ACC_06 | Onboarding interrotto durante la configurazione Player Card | Utente registrato come Giocatore ma Player Card incompleta | Al successivo accesso il sistema ripropone la configurazione interrotta; l'onboarding resta incompleto | UC_ACC_1 E3 |
| TF_ACC_07 | Credenziali corrette; campi presenti | Account esistente | L'utente accede con il proprio account e il sistema consente l'accesso alle funzionalita' previste | RF_ACC_3 - autenticazione |
| TF_ACC_08 | Credenziali errate oppure campi mancanti | Account esistente o modulo incompleto | Il login non viene effettuato e il sistema richiede credenziali corrette senza autenticare l'utente | RF_ACC_3 - errore autenticazione |
| TF_ACC_09 | Sessione autenticata; logout richiesto | Utente autenticato | La sessione viene terminata e l'utente viene riportato fuori dall'area autenticata | RF_ACC_3 - logout |
| TF_ACC_10 | Email associata a Account esistente; collegamento valido; nuova password conforme | Account esistente con email registrata | Il sistema invia la richiesta di recupero, verifica l'indirizzo tramite email e consente l'impostazione della nuova password | RF_ACC_4 - recupero password |
| TF_ACC_11 | Email non registrata | Nessun Account con l'email inserita | Il recupero non viene avviato e il sistema segnala che l'email non e' associata a un account | RF_ACC_4 - errore email |
| TF_ACC_12 | Collegamento scaduto o non valido | Recupero richiesto in precedenza con collegamento non valido | Il recupero non viene completato e il sistema richiede una nuova procedura di recupero | RF_ACC_4 - collegamento non valido |
| TF_ACC_13 | Nuova password debole o non conforme | Collegamento di recupero valido | La nuova password non viene impostata e il sistema mostra l'errore specifico | RF_ACC_4 - password non valida |

Totale frame ACC: 13

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_LEG_01 | Nome unico; 5vs5; privacy Privata; dati validi | Giocatore autenticato nella sezione Leghe | La lega viene registrata, il Giocatore diventa Amministratore della lega, viene generato un codice d'invito univoco e viene mostrata la dashboard | UC_LEG_1 flusso principale, passi 1-4 |
| TF_LEG_02 | Nome unico; tipologia valida; privacy Pubblica | Giocatore autenticato nella sezione Leghe | La lega viene registrata, resa visibile nella ricerca globale e diventa accessibile direttamente ai giocatori senza codice d'invito | UC_LEG_1 A1 |
| TF_LEG_03 | Nome duplicato | Esiste gia' una lega con lo stesso nome | Il sistema rileva il nome gia' in uso, mostra un errore ed evidenzia il campo da correggere; la creazione resta al passo 2 senza modifiche | UC_LEG_1 E1 |
| TF_LEG_04 | Nome vuoto o dati non validi | Modulo di creazione incompleto o con dati non validi | Il sistema rileva l'errore nei dati, mostra un messaggio ed evidenzia i campi da correggere; l'utente resta al modulo | UC_LEG_1 E1 |
| TF_LEG_05 | Tipologia non ammessa | Modulo con valore diverso dai formati 5vs5..11vs11 | La lega non viene creata e il sistema evidenzia la tipologia da correggere | UC_LEG_1 passo 2 / RF_LEG_1 |
| TF_LEG_06 | Creazione valida; invito condiviso | Lega creata dall'Amministratore | Viene generato e condiviso il codice d'invito univoco | UC_LEG_1 passi 4-5; RF_LEG_2 |
| TF_LEG_07 | Codice valido e non scaduto; adesione manuale | Lega privata esistente e secondo Giocatore autenticato | Il codice viene verificato, il Giocatore viene aggiunto ai membri e la dashboard viene aggiornata | UC_LEG_1 passo 7 |
| TF_LEG_08 | Codice errato o non associato a una lega | Giocatore autenticato nella sezione Leghe | Il sistema non trova alcuna lega, notifica l'errore e richiede un nuovo inserimento; il Giocatore non viene aggiunto | UC_LEG_1 E2 |
| TF_LEG_09 | Codice scaduto | Lega esistente con codice oltre la scadenza | Il sistema informa che il codice e' scaduto, richiede un nuovo inserimento e non aggiunge il Giocatore | UC_LEG_1 E2 |
| TF_LEG_10 | Link valido con invito non scaduto | Secondo Giocatore riceve il link di invito | Il sistema verifica il link e aggiunge il Giocatore ai membri della lega | RF_LEG_2 |
| TF_LEG_11 | Lega Pubblica; accesso diretto | Giocatore autenticato cerca o apre una lega pubblica | Il Giocatore accede direttamente alla lega senza inserire un codice e viene aggiunto ai membri | UC_LEG_1 A1 |
| TF_LEG_12 | Lega Privata; nessun invito valido | Giocatore autenticato tenta l'accesso diretto a una lega privata | Il tentativo di accesso diretto non aggiunge il Giocatore ai membri; per unirsi alla lega privata occorre inserire il codice d'invito o accedere tramite link | UC_LEG_1 A1; RF_LEG_2; RNF_U_2 |
| TF_LEG_13 | Amministratore; promozione membro | Lega con un membro ordinario | Il membro viene promosso ad Amministratore e conserva l'appartenenza alla lega | RF_LEG_3 |
| TF_LEG_14 | Amministratore; rimozione membro | Lega con almeno un altro membro o Amministratore | Il membro viene rimosso dalla lega e la lista dei membri viene aggiornata | RF_LEG_3 |
| TF_LEG_15 | Membro senza permesso; promozione o rimozione | Utente membro ordinario nella dashboard della lega | L'operazione non viene effettuata perche' riservata agli Amministratori | RF_LEG_3 |
| TF_LEG_16 | Giocatore membro; accesso alla dashboard | Utente autenticato appartenente alla lega | La dashboard mostra informazioni della lega, membri, prossime partite, storico incontri e classifica con gol e assist | RF_LEG_4 |
| TF_LEG_17 | Giocatore non membro; accesso alla dashboard | Utente autenticato che non appartiene alla lega | L'accesso alla dashboard della lega non viene concesso | RF_LEG_4 |
| TF_LEG_18 | Amministratore modifica nome, formato o privacy con dati validi | Lega esistente creata dall'Amministratore | I dettagli della lega vengono modificati e la dashboard mostra i dati aggiornati | RF_LEG_1 |

Totale frame LEG: 18
