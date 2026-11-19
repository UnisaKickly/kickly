# Requisiti funzionali e non funzionali

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | RAD v2.9, sezioni 3.2, 3.3 e 3.4.4.1 |
| **Versione** | 0.1 |
| **Data** | 19/11/2026 |
| **Autori** | Gabriele Karol Vicinanza |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 19/11/2026 | 0.1 | Prima stesura dei requisiti RAD v2.9 | <Nomi> |

## Indice

1. [Requisiti funzionali](#32-requisiti-funzionali)
2. [Requisiti non funzionali](#33-requisiti-non-funzionali)
3. [Tabella degli oggetti](#3441-tabella-degli-oggetti)

## 3.2 Requisiti funzionali

Nella presente sezione sono riassunti i requisiti funzionali del sistema proposto.

I requisiti sono raggruppati in 6 gestioni, corrispondenti alle aree di sistema descritte nel paragrafo 3.1: a ciascuna è associato un obiettivo, e i requisiti che la compongono sono quelli necessari a raggiungerlo.

Le gestioni individuate sono:
- Login e Onboarding (RF_ACC);
- Gestione Leghe e Inviti (RF_LEG);
- Gestione Pagamenti (RF_PAG);
- Rete Sociale e Sicurezza (RF_SS);
- Partite e RSVP (RF_PAR);
- Voto MVP e Notifiche (RF_POS, RF_NOT).

### RF_ACC: LOGIN E ONBOARDING

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_ACC_1 | RegistrazioneGestore | Il sistema deve permettere a un nuovo utente di registrarsi (inserimento dati relativi al campo) e, durante l’onboarding scegliere in modo definitivo il ruolo “Gestore del Campo”, venendo reindirizzato alla configurazione della propria struttura sportiva (numero di campi, tariffe, orari di disponibilità). | Alta |
| RF_ACC_2 | RegistrazioneGiocatore | Il sistema deve permettere a un nuovo utente di registrarsi (inserimento dati anagrafici) e, durante l’onboarding, scegliere in modo definitivo il ruolo “Giocatore”, configurando la propria Player Card (posizione, piede dominante, più aggiunta di dati anagrafici già definiti). | Alta |
| RF_ACC_3 | Autenticazione | Il sistema deve permettere a un utente già registrato (Giocatore o Gestore del Campo) di accedere (login) e disconnettersi (logout) dal proprio account in modo sicuro, utilizzando le credenziali fornite in fase di registrazione. | Alta |
| RF_ACC_4 | RecuperoPassword | Il sistema deve permettere ad un utente che ha dimenticato la password di reimpostarla tramite verifica dell’indirizzo email associato al proprio account. | Media |

### RF_LEG: GESTIONE LEGHE E INVITI

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_LEG_1 | CreazioneEGestioneLega | Il sistema deve permettere a un Giocatore di creare una nuova lega specificandone il nome, la tipologia di partita ( 5vs5, 6v6, 7v7, 8vs8, 9v9, 10v10, 11vs11 ) e livello di privacy (pubblica o privata), assumendo il ruolo di amministratore della lega e potendone modificare i dettagli | Alta |
| RF_LEG_2 | GeneratoreEGestioneInviti | Il sistema deve permettere all’amministratore della lega di generare e condividere un codice o link di invito, e deve permettere gli altri Giocatori di unirsi alla lega tramite l’inserimento manuale del codice o l’accesso diretto via link | Alta |
| RF_LEG_3 | GestioneMembriEAmministrazioneDellaLega | Il sistema deve permettere all'amministratore della lega di visualizzare la lista dei membri, promuovere un altro giocatore ad amministratore o rimuovere un membro dalla lega. | Media |
| RF_LEG_4 | VisualizzazioneDashboardEDettagliLega | Il sistema deve permettere a ciascun Giocatore appartenente ad una lega di visualizzarne la dashboard con le informazioni generali, la lista dei partecipanti, le prossime partite in programma e lo storico degli incontri della lega,classifica statistiche giocatori (goal e assist) | Alta |

### RF_PAG: GESTIONE PAGAMENTI

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_PAG_1 | PagamentoQuota | Il sistema deve permettere al Giocatore di poter versare la propria quota di partecipazione entro il termine indicato, una volta raggiunto il numero di partecipanti previsto per la partita. | Alta |
| RF_PAG_2 | RicezionePagamentoCampo | Il gestore del campo deve ricevere l’importo dovuto per lo slot prenotato, al netto della commissione trattenuta dalla piattaforma. | Alta |
| RF_PAG_3 | RimborsoQuote | Se la partita viene annullata dall’organizzatore o per mancato versamento di una o più quote entro il termine previsto, il sistema deve rimborsare ai giocatori le quote già versate. | Alta |
| RF_PAG_4 | StatoPagamenti | Il sistema deve permettere al Giocatore di visualizzare il numero di quote ancora da versare per la partita a cui è iscritto. | Media |

### RF_SS: RETE SOCIALE E SICUREZZA

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_SS_1 | CondivisionePartita | Il sistema deve permettere di generare un link univoco o un invito per una partita pubblica (ossia una singola partita non appartenente ad alcuna lega), condivisibile dagli utenti tramite app di messaggistica esterne (es. WhatsApp, Telegram). | Media |
| RF_SS_2 | AccessoSospetto | Il sistema deve inviare un'email di allerta (security alert) all'utente qualora venga rilevato un login al suo account da un dispositivo mai registrato in precedenza. | Media |

### RF_PAR: PARTITE E RSVP

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_PAR_1 | CreazionePartita | Il sistema deve permettere a un Giocatore (Organizzatore) di creare una nuova partita definendo i parametri fondamentali: data, ora, struttura sportiva (campo), numero di partecipanti richiesti, privacy (pubblica/privata) e tipologia (es. 5vs5, 7vs7). Il costo della singola quota per giocatore verrà poi calcolato dal sistema seguendo la tariffa del campo. | Alta |
| RF_PAR_2 | GestioneRSVP | Il sistema deve permettere a un Giocatore di confermare o declinare la propria partecipazione a una partita specifica, aggiornando dinamicamente e in tempo reale il contatore dei posti ancora disponibili. | Alta |
| RF_PAR_3 | AnnullamentoPartita | Il sistema deve permettere a un Giocatore (Organizzatore) di annullare una partita precedentemente creata entro un tempo limite prestabilito, innescando automaticamente l'aggiornamento dello stato dell'evento, l'invio della notifica di cancellazione agli iscritti e lo sblocco dello slot prenotato presso la struttura sportiva. | Alta |

### RF_POS, RF_NOT: VOTO MVP E NOTIFICHE

| ID | NOME | DESCRIZIONE | PRIORITÀ |
|---|---|---|---|
| RF_POS_1 | VotoMVP | Il sistema deve permettere a un giocatore di votare il miglior giocatore in campo (MVP) al termine di una partita conclusa. | Alta |
| RF_NOT_1 | NotificheDiServizio | Il sistema deve inviare notifiche in-app agli utenti per segnalare eventi rilevanti, come la ricezione di apertura sondaggio MVP o l'apertura delle convocazioni per una partita. | Alta |
| RF_POS_2 | StatisticaGiocatori | Il sistema deve permettere all'utente di consultare la classifica dei giocatori con più titoli MVP e le relative statistiche (goal e assist). | Media |
| RF_NOT_2 | GestionePreferenzeNotifiche | Il sistema deve consentire all'utente di attivare, disattivare o personalizzare le tipologie di notifiche da ricevere. | Media |

### 3.2.4 User stories

#### USER STORIES: LOGIN E ONBOARDING

| User stories | Requisito correlato |
|---|---|
| In quanto nuovo utente che vuole gestire un campo, voglio registrarmi e scegliere il ruolo “Gestoredel Campo” durante l’onboarding, in modo da iniziare subito a configurare la mia struttura sportiva. | RF_ACC_1 |
| In quanto nuovo utente che vuole giocare, voglio registrarmi, scegliere il ruolo “Giocatore” e configurare la mia Player Card, in modo da iniziare ad organizzare o partecipare a partite con un profilo completo fin dal primo accesso. | RF_ACC_2 |
| In quanto utente registrato, voglio accedere e uscire dal mio account in modo sicuro, in modo da proteggere i miei dati personali. | RF_ACC_3 |
| In quanto utente che ha dimenticato la password, voglio poterla reimpostare tramite la mia email, in modo da recuperare l’accesso al mio account senza dover contattare il supporto. | RF_ACC_4 |

#### USER STORIES: LEGHE E INVITI

| User stories | Requisito correlato |
|---|---|
| In quanto Giocatore, voglio poter creare una nuova lega definendo nome, formato e livello di privacy, per organizzare un gruppo chiuso di utenti con cui pianificare partite ricorrenti | RF_LEG_1 |
| In quanto Giocatore, voglio potermi unire a una lega inserendo un codice di invito univoco o cliccando su un link di condivisione, per entrare a far parte del gruppo ed essere incluso nelle future partite della lega | RF_LEG_2 |
| In quanto Amministratore della lega, voglio poter rimuovere un membro o nominarne un altro admin, per gestire correttamente la community interna | RF_LEG_3 |
| In quanto Giocatore, voglio visualizzare la dashboard della mia lega, per consultare i membri, le prossime partite e lo storico. | RF_LEG_4 |

#### USER STORIES: PAGAMENTI

| User stories | Requisito correllato |
|---|---|
| In quanto Giocatore voglio poter versare la mia quota direttamente dall’applicazione per non dover gestire contanti o trasferimenti tra privati. | RF_PAG_1 |
| In quanto Gestore del Campo voglio ricevere l’importo dello slot prenotato tramite la piattaforma per non dover incassare dai singoli giocatori il giorno della partita. | RF_PAG_2 |
| In quanto Giocatore voglio essere rimborsato automaticamente se la partita viene annullata per non dover reclamare i soldi a chi l’aveva organizzata. | RF_PAG_3 |
| In quanto Giocatore, voglio visualizzare il numero di quote ancora da versare per sapere quanto manca alla conferma della partita senza doverlo chiedere nel gruppo. | RF_PAG_4 |

#### USER STORIES: RETE SOCIALE E SICUREZZA

| User stories | Requisito correlato |
|---|---|
| In quanto giocatore, vorrei poter condividere il link della partita a cui sono iscritto sulle mie app di messaggistica, in modo da invitare facilmente i miei amici esterni ad unirsi al match e raggiungere il numero di giocatori richiesto. | RF_SS_1 |
| In quanto utente registrato, vorrei ricevere un avviso di sicurezza via email se viene effettuato l'accesso al mio account da un nuovo dispositivo, in modo da poter intervenire tempestivamente in caso di furto di credenziali. | RF_SS_2 |

#### USER STORIES: PARTITE E RSVP

| User stories | Requisito correlato |
|---|---|
| Come Organizzatore, voglio poter creare una nuova partita inserendo tutti i dettagli logistici (data, ora, campo), affinché io possa generare l'evento nel sistema e permettere agli altri di iscriversi. | RF_PAR_1 |
| Come Giocatore, voglio poter confermare o rifiutare la mia presenza a una partita con un semplice tap (RSVP), affinché l'organizzatore sappia con certezza se ci sarò e il sistema possa eventualmente liberare il mio posto per altri. | RF_PAR_2 |
| Come Organizzatore, voglio poter annullare una partita in caso di imprevisti insormontabili, affinché il sistema possa liberare lo slot del campo, avvisare tempestivamente tutti gli iscritti e avviare le procedure di rimborso senza il mio intervento manuale. | RF_PAR_3 |

#### USER STORIES: VOTO MVP E NOTIFICHE

| User stories | Requisito correlato |
|---|---|
| In quanto giocatore, vorrei poter votare il migliore in campo (MVP) a fine partita in modo da contribuire alla classifica e permettere l'aggiornamento delle statistiche personali sulla dashboard. | RF_POS_1 |
| Come utente, vorrei ricevere notifiche tempestive in-app per quanto riguarda eventi rilevanti (come l’apertura del sondaggio MVP o l'apertura delle convocazioni) in modo da essere sempre aggiornato senza dover controllare continuamente le chat. | RF_NOT_1 |
| In quanto giocatore, vorrei visualizzare la classifica dei giocatori con più MVP, in modo da confrontare le mie statistiche con quelle degli amici e mantenere alta la competizione. | RF_POS_2 |
| Come utente, vorrei poter personalizzare le mie preferenze sulle notifiche, in modo da silenziare gli avvisi meno importanti e non essere disturbato quando non voglio. | RF_NOT_2 |

## 3.3 Requisiti non funzionali

In questa sezione sono formalizzati i requisiti non funzionali del sistema proposto. La trattazione riguarda gli aspetti di usabilità, affidabilità, prestazioni e supportabilità del software, i vincoli tecnologici di implementazione, le interfacce verso i servizi esterni (in particolare il fornitore di pagamento), le caratteristiche di packaging e i vincoli di conformità legale.

Ogni requisito è identificato da un ID, da un nome, da una descrizione, dalla priorità (Alta, Media, Bassa) e dalla difficoltà di realizzazione (Alta, Media, Bassa).

### 3.3.1 Usabilità

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_U_1 | OnboardingGiocatore | L’intera procedura di iscrizione e configurazione iniziale (dalla generazione del profilo fino alla definizione della Player Card e all’assegnazione del ruolo) deve svolgersi senza assistenza esterna, garantendo un’esperienza rapida completabile in meno di 3 minuti (riferimento: le linee guida UX sull’onboarding mobile indicano che un processo di registrazione che supera i 3–5 minuti genera un abbandono significativo da parte dell’utente) | Alta | Media |
| RNF_U_2 | UnioneALega | Il sistema deve permettere a un Giocatore autenticato di unirsi a una lega, privata o pubblica, inserendo il codice d’invito o accedendo tramite link di condivisione (correlato a RF_LEG_2), con un massimo di 3 interazioni e senza richiedere di reinserire dati già forniti. | Alta | Bassa |

### 3.3.2 Affidabilità

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_A_1 | ConsistenzaStatistichePlayerCard | ll sistema deve aggiornare le statistiche della Player Card (gol, assist, presenze, voti MVP) entro 1 minuto dalla chiusura di ciascun incontro (vincolo di progetto, per garantire una percezione di aggiornamento in tempo reale), conservarle senza perdite in caso di riavvio o malfunzionamento e mostrare valori coincidenti con lo storico degli incontri. | Alta | Media |
| RNF_A_2 | AffidabilitàAggiornamentoRSVP | Il sistema deve garantire che l’operazione di RSVP (conferma o ritiro) e il conseguente aggiornamento del contatore dei posti disponibili avvengano con un tasso di successo del 99,9% (riferimento: soglia di disponibilità standard “three nines”, comunemente adottata per servizi software di fascia media), assicurando che in nessun caso si verifichino situazioni di overbooking. | Alta | Media |
| RNF_A_3 | IntegritaTransazioniPagamento | In caso di interruzione della comunicazione con il fornitore di pagamento, il sistema non deve addebitare due volte la stessa quota né registrare come versata una quota il cui esito non è stato confermato | Alta | Alta |

### 3.3.3 Prestazioni

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_PRE_1 | NotificheStatoPartita | Il sistema deve recapitare le notifiche di aggiornamento sullo stato della partita entro un massimo di 5 minuti dall’evento scatenante (vincolo di progetto per notifiche non critiche). | Media | Media |
| RNF_PRE_2 | TempoRegistrazioneVotoMVP | Il sistema deve elaborare la registrazione del voto MVP entro un tempo massimo di 10 secondi per non bloccare l’interfaccia (riferimento: soglia di attenzione dell’utente in un’interazione — Nielsen, “Usability Engineering”, 1993: oltre i 10 secondi l’utente perde il focus sul compito). | Alta | Media |
| RNF_PRE_3 | TempestivitàRimborso | il rimborso deve essere disposto entro 5 giorni lavorativi dall’annullamento della partita nel 90% dei casi (riferimento: tempi standard di storno/rimborso bancario nell’area SEPA, generalmente entro 3–5 giorni lavorativi). | Alta | Alta |

### 3.3.4 Supportabilità

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_S_1 | EstensibilitàLegheEInviti | Il modulo “Leghe e inviti” deve essere progettato in modo modulare, così da permettere di aggiungere una nuova tipologia di lega (es. torneo a eliminazione diretta, campionato a gironi) o un nuovo canale di condivisione degli inviti senza modificare la logica di gestione dei membri | Bassa | Media |

### 3.3.5 Implementazione

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_IMP_1 | VincoliTecnologici | Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging. | Alta | Media |

### 3.3.6 Interfacce

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_IN_1 | SicurezzaDatiPagamento | Il sistema deve interfacciarsi con un fornitore esterno di servizi di pagamento per l’incasso delle quote e l’accredito al gestore del Campo; i dati delle carte e le coordinate bancarie non devono transitare né essere memorizzati dal sistema, che conserva unicamente l’identificativo dell’account presso il fornitore. | Alta | Alta |

### 3.3.7 Packaging

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_P_1 | PacchettoAutoconsistente | Il pacchetto di installazione dell’applicazione deve includere tutte le librerie e i framework necessari al funzionamento, senza richiedere all’utente di scaricare o installare altro software prima del primo avvio. Restano esclusi i servizi remoti (es. backend Supabase), che richiedono la connessione di rete. | Alta | Bassa |

### 3.3.8 Aspetti legali

| ID | NOME | DESCRIZIONE | Priorità | Difficoltà |
|---|---|---|---|---|
| RNF_L_1 | CancellazioneDatiPersonali | In conformità al diritto alla cancellazione previsto dal Regolamento (UE) 2016/679 (GDPR), a seguito della richiesta di eliminazione dell’account il sistema deve cancellare in modo definitivo tutti i dati personali dell’utente dai propri archivi entro 30 giorni (termine allineato a quello previsto dall’art. 12 GDPR per il riscontro alle richieste dell’interessato), salvo i dati che il sistema è tenuto a conservare per obblighi di legge (es. Le transazioni di pagamento) | Alta | Media |

## 3.4.4.1 Tabella degli oggetti

### 3.4.4.1.1 Login e Onboarding (UC_ACC_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| Account | Entity | Dati comuni, include ruoloAccount (Giocatore o GestoreCampo, distinto dalla posizione in campo), età, statoOnboarding, preferenzeNotifiche. |
| Giocatore | Entity | Specializzazione di Account. Possiede ruoloPreferitoInCampo e piedeDominante. Le statistiche sono calcolate tramite query su Partecipazione e VotazioneMVP (senza Entity PlayerCard separata). |
| GestoreCampo | Entity | Specializzazione di Account. Possiede idAccountPagamenti. Campi, tariffe e disponibilità sono raggiungibili tramite le associazioni. |
| RegistrazioneControl | Control | Gestisce registrazione, scelta ruolo, configurazione Player Card e ripresa dell'onboarding. Per il Gestore, richiama GestioneCampiControl e DashboardGestore (definiti nella sezione Pagamenti). |
| AutenticazioneControl | Control | Gestisce login e logout (RF_ACC_3). |
| RecuperoPasswordControl | Control | Realizza RF_ACC_4: gestisce il reset della password tramite verifica dell’indirizzo email. |
| ImpostazioniAccount | Boundary | Interfaccia utente (non Control) che richiama autenticazione, logout e cancellazione account. |
| FormRegistrazione | Boundary | Raccoglie i dati anagrafici, email e password durante la registrazione (UI_2, passi 1-3 di UC_ACC_1). |
| FormOnboarding | Boundary | Permette di scegliere il ruolo, Giocatore o Gestore del Campo (UI_3). |
| FormPlayerCard | Boundary | Raccoglie i dati di configurazione della Player Card: ruolo in campo e piede dominante (UI_4). |
| FormLogin | Boundary | Raccoglie le credenziali per l’accesso di un utente già registrato (UI_7, RF_ACC_3). |
| FormRecuperoPassword | Boundary | Consente di richiedere il recupero dell’accesso e impostare una nuova password |
| Dashboard | Boundary | Mostra la schermata principale dopo il login o il completamento dell’onboarding. Permette l'accesso alle proprie partite e alle partite pubbliche disponibili (bacheca). |
| ServizioEmail | Boundary | Servizio di posta elettronica condiviso e utilizzato sia per il recupero della password sia per l'invio dell'email di allerta in caso di accesso da un nuovo dispositivo. |

### 3.4.4.1.2 Leghe e Inviti (UC_LEG_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| Lega | Entity | Contiene i dati relativi a una competizione (nome, tipologia di match, livello di privacy). Assorbe il codice univoco di invito e la relativa scadenza. Membri e amministratori sono gestiti tramite associazione con Giocatore |
| GestioneLegaControl | Control | Realizza UC_LEG_1 (passi 1-4): gestisce validazione, controllo nomi duplicati, registrazione lega e nomina Amministratore. Esteso a: modifica dei dettagli, generazione invito, gestione membri/admin e consultazione dashboard. |
| GestioneAdesioneControl | Control | Realizza UC_LEG_1 (passi 5-7): gestisce l'ingresso tramite codice, ingresso tramite link, e l'accesso diretto per le leghe pubbliche, aggiungendo i nuovi membri. |
| FormLega | Boundary | Interfaccia riutilizzata sia per la creazione che per la modifica dei dettagli di una lega (nome, formato, privacy). |
| FormAdesioneLega | Boundary | Interfaccia della sezione "Leghe" in cui l'utente invitato inserisce e conferma il codice d’invito ricevuto. |
| DashboardLega | Boundary | Schermata di riepilogo della lega. Mostra codice d'invito, membri aggiornati, prossime partite, storico incontri, statistiche e i comandi riservati agli amministratori. |
| VistaLeghe | Boundary | Interfaccia che mostra l'elenco delle proprie leghe a cui si è iscritti e permette la ricerca delle leghe pubbliche. |

### 3.4.4.1.3 Partite e RSVP (UC_PAR_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| Partita | Entity | È il singolo evento sportivo creato dall’organizzatore |
| Campo | Entity | È l’impianto sportivo dove si svolgerà. Fornisce la tariffa da dividere e la rappresentazione degli orari di disponibilità. |
| Prenotazione | Entity | Collega una Partita a un Campo per un intervallo temporale. Conserva stato e scadenza del blocco, costo concordato, quota individuale (calcolata dai costi e dai partecipanti), commissione e netto destinato al gestore. |
| Partecipazione | Entity | Associazione univoca (impedisce duplicati) tra un Giocatore e una Partita. Rappresenta risposta/stato, data della risposta, gol e assist della singola partita per ricavare le statistiche. |
| PrenotazioneControl | Control | Gestisce la verifica della disponibilità del Campo, il blocco temporaneo, la conferma e la liberazione dello slot. |
| GestionePartitaControl | Control | Coordina la creazione, il riepilogo e l'annullamento della partita. |
| GestionePartecipazioneControl | Control | Realizza RF_PAR_2 e lo scenario SC_PAR_2: gestisce l'aggiornamento dinamico dei posti disponibili, impedendo il superamento della capienza. |
| FormCreazionePartita | Boundary | Raccoglie i parametri della partita, permette la scelta del campo e mostra disponibilità e riepilogo dei costi |
| DettaglioPartita | Boundary | Mostra informazioni, partecipanti e quote mancanti. Consente RSVP, annullamento, accesso al pagamento e condivisione, secondo i permessi |

### 3.4.4.1.4 Voto MVP, Classifica e Notifiche (UC_MVP_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| VotazioneMVP | Entity | Collegata alla Partita (copre partite di lega ed esterne). Rappresenta stato, eventuale scadenza, preferenze votante-votato (con il vincolo di un solo voto per giocatore nella stessa votazione) e identifica il vincitore. |
| Notifica | Entity | Contiene i dati di una notifica in-app: destinatario, tipo, messaggio, data (timestamp) e stato di lettura. |
| VotoMVPControl | Control | Realizza lo UC_MVP_1: raccoglie il voto, verifica che non sia duplicato per la stessa partita, aggiorna le statistiche e determina il vincitore. |
| ClassificaControl | Control | Realizza RF_POS_2: calcola e mostra la classifica dei giocatori distinguendo i voti ricevuti e i titoli MVP vinti, oltre a gol e assist. |
| NotificaControl | Control | Realizza RF_NOT_1 e lo scenario SC_NOT_1: gestisce l'invio delle notifiche in-app, la loro consultazione e l'aggiornamento dello stato di lettura. |
| PreferenzeNotificheControl | Control | Realizza RF_NOT_2: gestisce l'attivazione, disattivazione e personalizzazione delle notifiche, aggiornando le preferenze salvate nell'Account. |
| FormVotoMVP | Boundary | Mostra l’elenco dei giocatori della partita conclusa e permette di esprimere il voto MVP (passi 1-3 di UC_MVP_1). |
| VistaClassifica | Boundary | Mostra la classifica dei giocatori in base a voti MVP, gol e assist (RF_POS_2). |
| PannelloNotifiche | Boundary | Mostra le notifiche in-app ricevute e permette di aprirle (SC_NOT_1). |
| ImpostazioniNotifiche | Boundary | Permette di attivare, disattivare o personalizzare le notifiche (RF_NOT_2). |

### 3.4.4.1.5 Pagamento del Campo (UC_PAG_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| Quota | Entity | Rappresenta quanto dovuto. Contiene i dati relativi alla quota di partecipazione dovuta da un giocatore per una partita, con il relativo stato di versamento. È collegata alla specifica Partecipazione. |
| Transazione | Entity | Registra un’operazione economica di tipo pagamento, rimborso o accredito (non è obbligatoriamente collegata a una singola Quota). Il pagamento è riferito alla Quota, il rimborso al pagamento originario, l'accredito alla Prenotazione e al Gestore destinatario. Conserva importo, stato, date e riferimento esterno. |
| GestioneTransazioniControl | Control | Realizza UC_PAG_1 e i requisiti RF_PAG_1, RF_PAG_2, RF_PAG_3: coordina pagamenti, rimborsi e accrediti attraverso GatewayPagamenti. Registra gli esiti, evita duplicazioni, segnala il completamento di tutte le quote, esplicita la gestione delle scadenze e il coordinamento dell'annullamento. |
| GestioneCampiControl | Control | Realizza la configurazione della struttura introdotta in RF_ACC_1:Coordina configurazione e modifica dei campi, delle tariffe e delle disponibilità, verificando che l’utente sia il gestore autorizzato |
| InterfacciaPagamento | Boundary | mostra quota e scadenza, raccoglie la conferma per procedere e comunica lo stato dell’operazione e dell’eventuale rimborso |
| GatewayPagamenti | Boundary | Gestisce lo scambio di richieste ed esiti tra Kickly e il fornitore esterno per pagamenti, rimborsi ed accrediti |
| DashboardGestore | Boundary | Permette di configurare campi, tariffe e disponibilità e consultare prenotazione e accrediti |

### 3.4.4.1.6 Rete Sociale, Sicurezza e GDPR (UC_SS_1)

| Nome | Tipo | Descrizione |
|---|---|---|
| DispositivoRegistrato | Entity | Conserva il riferimento di un dispositivo già utilizzato per accedere ad un Account, con primo e ultimo accesso. Permette di riconoscere accessi da nuovi dispositivi |
| GestioneCondivisioneControl | Control | Realizza UC_SS_1: gestisce la logica di generazione del link univoco della partita e l'invocazione del menu di condivisione nativo. |
| SicurezzaAccessiControl | Control | Realizza RF_SS_2 e lo scenario SC_SS_2:confronta il dispositivo di accesso con quelli registrati, registra il nuovo dispositivo e richiede l’invio dell’email di allerta. |
| CancellazioneAccountControl | Control | Realizza RNF_L_1: coordina la richiesta di cancellazione dell’Account e il trattamento dei dati. |
| MenuCondivisione | Boundary | Rappresenta l'interfaccia mostrata all'utente per selezionare l'app di messaggistica o copiare il link).(passi 3-5 di UC_SS_1). |
| ServizioEmail | Boundary | Servizio di posta elettronica condiviso e utilizzato sia per il recupero della password sia per l'invio dell'email di allerta in caso di accesso da un nuovo dispositivo. |
