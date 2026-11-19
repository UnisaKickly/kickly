# Category partition - UC_MVP_1 Assegnazione voto MVP della partita e UC_SS_1 Condivisione partita

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/UC_MVP_1_VotoMVP.md`, `docs/rad/uc/UC_SS_1_CondivisionePartita.md` |
| **Requisiti** | RF_POS_1, RF_POS_2, RF_NOT_1, RF_NOT_2, RF_SS_1, RF_SS_2, RNF_A_1, RNF_PRE_2, RNF_L_1 |
| **Metodo testato** | Classi `VotoMVPControl`, `ClassificaControl`, `NotificaControl`, `PreferenzeNotificheControl`, `GestioneCondivisioneControl`, `SicurezzaAccessiControl` e `CancellazioneAccountControl` come definite nella tabella degli oggetti dei casi d'uso. Il RAD non documenta firme o metodi di tali classi. |
| **Autori** | Copilot |
| **Revisori** | Mario Celzo, Renato Mancino |

Fonti degli esiti attesi: i casi d'uso UC_MVP_1 e UC_SS_1, RAD v2.9 §3.2 per RF_POS_1, RF_POS_2, RF_NOT_1, RF_NOT_2, RF_SS_1, RF_SS_2 e RNF_L_1, RAD §3.3 per RNF_A_1 e RNF_PRE_2 e §3.4 per la tabella degli oggetti. Dove il caso d'uso non descrive un esito esplicito, il frame usa esclusivamente il requisito collegato o l'assenza di effetto definita dallo stato iniziale. Non sono usati comportamenti dedotti dal codice.

## 1. Parametri e condizioni dell'ambiente

| Parametro / condizione | Descrizione |
|---|---|
| Stato della partita | partita Conclusa o in stato diverso da Conclusa |
| Partecipazione del votante | il Giocatore votante partecipa o meno alla partita |
| Voto precedente | il votante ha gia' espresso oppure no un voto nella stessa `VotazioneMVP` |
| Connessione alla conferma | server raggiungibile oppure non raggiungibile durante la conferma del voto |
| Connessione all'accesso alla sezione | server raggiungibile oppure non raggiungibile durante l'accesso alla sezione della partita |
| Tempo di elaborazione del voto | elaborazione entro il limite previsto oppure oltre il limite previsto |
| Aggiornamento statistiche | statistiche aggiornate entro il limite previsto, conservate senza perdite o non coerenti |
| Dati della classifica | titoli MVP, gol e assist disponibili; dati assenti |
| Pareggio della classifica | giocatori con titoli MVP differenti oppure a pari merito |
| Preferenza notifiche | tipologia notifiche attiva, disattiva o personalizzata nell'`Account` |
| Evento di notifica | apertura sondaggio MVP o altra apertura convocazione |
| Stato lettura della notifica | letta o non letta |
| Privacita' della partita | partita pubblica o non pubblica |
| Iscrizione del Giocatore | il Giocatore e' iscritto oppure no alla partita pubblica |
| Esito della condivisione | link copiato, app di terze parti selezionata o menu annullato |
| Connessione alla condivisione | server raggiungibile oppure non raggiungibile nella generazione del link |
| Dispositivo di accesso | gia' registrato oppure nuovo per l'`Account` |
| Stato della cancellazione | richiesta di cancellazione dell'`Account` e dati personali associati |
| Transazioni da conservare | nessuna oppure transazioni soggette agli obblighi di legge, da mantenere dissociate dall'`Account` |

## 2. Categorie e scelte

### Stato della partita

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato partita | conclusa | `[property PartitaConclusa]` |
| Stato partita | diversa da conclusa | `[error]` |

### Partecipazione e voto precedente

| Categoria | Scelta | Vincolo |
|---|---|---|
| Partecipazione | il votante partecipa alla partita | `[if PartitaConclusa] [property VotantePartecipante]` |
| Partecipazione | il votante non partecipa alla partita | `[if PartitaConclusa] [error]` |
| Voto precedente | nessun voto espresso nella stessa votazione | `[if VotantePartecipante] [property NessunVotoPrecedente]` |
| Voto precedente | voto gia' espresso nella stessa votazione | `[if VotantePartecipante] [error]` |

### Connessione alla sezione e alla conferma del voto

| Categoria | Scelta | Vincolo |
|---|---|---|
| Accesso alla sezione | server raggiungibile | |
| Accesso alla sezione | server non raggiungibile | `[error] [single]` |
| Conferma del voto | server raggiungibile | `[if NessunVotoPrecedente] [property ConnessioneVotoAttiva]` |
| Conferma del voto | server non raggiungibile | `[if NessunVotoPrecedente] [error] [single]` |

### Tempi e consistenza delle statistiche MVP

| Categoria | Scelta | Vincolo |
|---|---|---|
| Tempo di elaborazione | voto elaborato entro 10 secondi | `[property ElaborazioneVotoEntroLimite]` |
| Tempo di elaborazione | voto elaborato oltre 10 secondi | `[error] [single]` |
| Aggiornamento statistiche | statistiche aggiornate entro 1 minuto e coerenti con lo storico | `[property StatisticheCoerenti]` |
| Aggiornamento statistiche | dati persi o non coerenti con lo storico dopo un riavvio o malfunzionamento | `[error] [single]` |

### Dati della classifica

| Categoria | Scelta | Vincolo |
|---|---|---|
| Dati disponibili | titoli MVP, gol e assist presenti | `[property ClassificaCompleta]` |
| Dati disponibili | uno o piu' valori non disponibili | `[single]` |
| Pareggio | giocatori con titoli MVP differenti | |
| Pareggio | giocatori a pari merito | `[if ClassificaCompleta] [single]` |

### Preferenze notifiche

| Categoria | Scelta | Vincolo |
|---|---|---|
| Preferenza | tipologia attiva | `[property NotificaAttiva]` |
| Preferenza | tipologia disattivata | `[error]` |
| Preferenza | tipologia personalizzata dall'utente | `[property PreferenzaPersonalizzata] [single]` |

### Evento e stato della notifica

| Categoria | Scelta | Vincolo |
|---|---|---|
| Evento rilevante | apertura sondaggio MVP | `[if NotificaAttiva] [property AperturaSondaggioMVP]` |
| Evento rilevante | apertura convocazione per una partita | `[if NotificaAttiva] [property AperturaConvocazioni] [single]` |
| Stato lettura | non letta | `[property NotificaNonLetta]` |
| Stato lettura | letta | `[if NotificaNonLetta] [single] [property NotificaLetta]` |

### Privacita', iscrizione e condivisione

| Categoria | Scelta | Vincolo |
|---|---|---|
| Privacita' | partita pubblica | `[property PartitaPubblica]` |
| Privacita' | partita non pubblica | `[error]` |
| Iscrizione | Giocatore iscritto alla partita pubblica | `[if PartitaPubblica] [property Iscritto]` |
| Iscrizione | Giocatore non iscritto alla partita pubblica | `[if PartitaPubblica] [error]` |
| Azione utente | copia il link | `[if Iscritto] [property LinkCopiato]` |
| Azione utente | seleziona un'app di terze parti | `[if Iscritto] [property AppTerzaSelezionata]` |
| Azione utente | annulla il menu senza selezionare | `[if Iscritto] [single]` |

### Connessione alla condivisione

| Categoria | Scelta | Vincolo |
|---|---|---|
| Server | raggiungibile | `[if Iscritto] [property LinkGenerabile]` |
| Server | non raggiungibile | `[if Iscritto] [error]` |

### Dispositivo di accesso

| Categoria | Scelta | Vincolo |
|---|---|---|
| Dispositivo | gia' registrato per l'Account | |
| Dispositivo | nuovo per l'Account | `[property DispositivoNuovo] [single]` |

### Cancellazione Account

| Categoria | Scelta | Vincolo |
|---|---|---|
| Dati personali | presenti negli archivi del sistema | `[property DatiPersonaliPresenti]` |
| Transazioni | nessuna transazione da conservare | `[if DatiPersonaliPresenti]` |
| Transazioni | una o piu' transazioni soggette ad obblighi di legge | `[if DatiPersonaliPresenti] [property TransazioniDaConservare] [single]` |

## 3. Test frame

L'esito atteso deriva dai casi d'uso, dal RAD v2.9 §3.2 e dalla tabella degli oggetti del §3.4. Ogni frame ha un test con l'id in minuscolo nel nome in un ticket successivo che implementa il relativo Control.

### 3.1 Voto MVP e classifica (UC_MVP_1, RF_POS_1 e RF_POS_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_MVP_01 | partita conclusa, votante partecipante, nessun voto precedente, connessione raggiungibile | Giocatore autenticato nella sezione dettaglio di una partita conclusa; la votazione contiene il suo voto non ancora espresso | Il voto viene registrato nella `VotazioneMVP`, la statistica del Giocatore votato viene aggiornata e la conferma mostra un messaggio di successo | UC_MVP_1, passi 1-6; RF_POS_1 |
| TF_MVP_02 | partita conclusa, votante partecipante, voto precedente gia' espresso | Giocatore autenticato che ha gia' espresso un voto nella stessa partita | L'operazione viene bloccata, il voto precedente resta invariato e viene mostrato un messaggio di avviso | UC_MVP_1, flusso alternativo 3.1 |
| TF_MVP_03 | partita conclusa, votante non partecipante | Giocatore autenticato che tenta di votare per una partita a cui non ha partecipato | Il voto non viene registrato e il Giocatore viene avvisato dell'errore | UC_MVP_1, exit condition on failure; vincolo votante partecipante descritto dall'uso della lista dei partecipanti |
| TF_MVP_04 | partita diversa da conclusa | Giocatore autenticato nella sezione dettaglio di una partita non conclusa | Il sistema non permette la registrazione del voto e il votante viene avvisato che la partita non ha ancora concluso | UC_MVP_1, entry condition |
| TF_MVP_05 | partita conclusa, votante partecipante, nessun voto precedente, server non raggiungibile | Connessione assente al momento della conferma del voto | Il voto non viene registrato e il sistema invita il votante a riprovare più tardi | UC_MVP_1, flusso di errore 4.1 |
| TF_MVP_06 | dati della classifica disponibili, titoli MVP, gol e assist presenti | Partita o votazione concluse e dati statistici disponibili | `ClassificaControl` mostra i giocatori con titoli MVP, voti ricevuti, gol e assist secondo la classifica prevista da RF_POS_2 | RF_POS_2 |
| TF_MVP_07 | dati della classifica disponibili, valori assenti | La classifica contiene uno o più valori statistici non disponibili | Vengono mostrati solo i dati disponibili e nessuna voce viene nascosta solo perché priva di un dato; non vengono inventati valori | RF_POS_2 |
| TF_MVP_08 | dati della classifica disponibili, giocatori a pari merito | Due giocatori hanno lo stesso numero di titoli MVP e i dati statistici sono disponibili | Il pareggio è rappresentato senza creare posizioni artificiali o inventare valori | RF_POS_2 |
| TF_MVP_09 | accesso alla sezione con server non raggiungibile | Giocatore autenticato tenta di accedere alla sezione di dettaglio di una partita conclusa senza connessione | Il sistema notifica l'errore e invita il Giocatore a riprovare più tardi, senza registrare alcun voto | UC_MVP_1, flusso di errore 1.1 |
| TF_MVP_10 | voto elaborato oltre 10 secondi | Giocatore conferma un voto e l'elaborazione supera il limite previsto dal requisito | L'elaborazione non viene completata oltre il limite e il Giocatore viene informato dell'esito, senza registrazione incompleta del voto | RNF_PRE_2 |
| TF_MVP_11 | statistiche perse o non coerenti dopo riavvio o malfunzionamento | Le statistiche del Giocatore votato non sono conservate o non coincidono con lo storico dopo un riavvio o malfunzionamento | Le statistiche non vengono perse e restano coerenti con lo storico degli incontri entro il limite previsto | RNF_A_1 |

### 3.2 Notifiche (RF_NOT_1 e RF_NOT_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_NOT_01 | preferenza attiva, evento apertura sondaggio MVP | Votazione MVP appena aperta per una partita conclusa e Account destinatario con tipologia attiva | Una `Notifica` in-app viene inviata all'Account destinatario con tipo, messaggio e timestamp coerenti con l'apertura del sondaggio MVP | RF_NOT_1 |
| TF_NOT_02 | preferenza attiva | Si verifica un evento rilevante per il quale la tipologia e' attiva | La notifica viene registrata e consultabile nel `PannelloNotifiche` | RF_NOT_1 |
| TF_NOT_03 | preferenza disattivata | Si verifica un evento rilevante e l'utente ha disattivato la relativa tipologia | Non viene inviata la notifica relativa a quella tipologia; l'utente resta sulla configurazione delle preferenze salvate | RF_NOT_2 |
| TF_NOT_04 | preferenza attiva, notifica non letta, consultazione | Account con una notifica in-app non letta | Aprendo la notifica lo stato di lettura viene aggiornato e la `Notifica` resta consultabile | Tabella degli oggetti: `NotificaControl`, attributo statoLettura |
| TF_NOT_05 | preferenza personalizzata dall'utente | L'Account contiene una configurazione personalizzata per una tipologia di notifica | Il sistema conserva la configurazione personalizzata dell'Account e applica la relativa tipologia | RF_NOT_2 |
| TF_NOT_06 | preferenza attiva, apertura convocazione per una partita | Si apre la convocazione per una partita e l'Account ha attiva la relativa tipologia | Una `Notifica` in-app viene inviata all'Account con dati coerenti con l'apertura della convocazione | RF_NOT_1, apertura convocazioni descritta nel requisito |

### 3.3 Condivisione partita e sicurezza account (UC_SS_1, RF_SS_1, RF_SS_2 e RNF_L_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_SS_01 | partita pubblica, Giocatore iscritto, server raggiungibile | Giocatore autenticato nella schermata di dettaglio di una partita pubblica a cui e' iscritto | Il sistema genera un URI/link univoco associato alla partita e apre il menu di condivisione nativo | UC_SS_1, passi 1-3; RF_SS_1 |
| TF_SS_02 | partita pubblica, iscritto, link generabile, azione copia link | Link generato e l'utente seleziona `Copia link` nel menu nativo | Il link viene copiato e il sistema mostra il messaggio di successo `Link copiato!` | UC_SS_1, passo 5 |
| TF_SS_03 | partita pubblica, iscritto, link generabile, app di terze parti selezionata | Link generato e l'utente seleziona WhatsApp, Telegram o altra app disponibile | Il sistema apre l'applicazione selezionata con il link della partita disponibile per la condivisione | UC_SS_1, passo 5 |
| TF_SS_04 | partita pubblica, iscritto, link generabile, menu annullato | Link generato ma l'utente chiude il menu senza selezionare alcuna opzione | La condivisione viene annullata e il Giocatore resta sulla schermata di dettaglio della partita | UC_SS_1, flusso alternativo A1 |
| TF_SS_05 | partita pubblica, iscritto, server non raggiungibile | Connessione assente mentre il sistema tenta di generare il link | Nessun link viene generato; il sistema notifica l'errore e invita a riprovare, riprendendo dalla selezione `Condividi` | UC_SS_1, flusso di errore E1 |
| TF_SS_10 | partita non pubblica | Giocatore tenta di accedere alla condivisione di una partita non pubblica | La condivisione non viene resa disponibile perché contraria alla condizione entry di UC_SS_1 e a RF_SS_1 | UC_SS_1, entry condition; RF_SS_1 |
| TF_SS_11 | partita pubblica, Giocatore non iscritto | Giocatore autenticato tenta di accedere alla condivisione di una partita pubblica a cui non risulta iscritto | La condivisione viene bloccata e il Giocatore resta sulla schermata della partita | UC_SS_1, entry condition |
| TF_SS_06 | dispositivo gia' registrato per l'Account | Account autenticato da un dispositivo presente in `DispositivoRegistrato` | Il dispositivo non viene duplicato e non viene richiesto l'invio di alcuna email di allerta | RF_SS_2 |
| TF_SS_07 | nuovo dispositivo per l'Account | Account autenticato da un identificativo non presente tra i dispositivi dell'Account | Il nuovo `DispositivoRegistrato` viene registrato con primo e ultimo accesso e il sistema richiede l'invio dell'email di allerta tramite `ServizioEmail` | RF_SS_2, scenario SC_SS_2 |
| TF_SS_08 | Account con dati personali presenti, nessuna transazione da conservare | Account cancellabile con dati personali negli archivi e senza vincoli legali di conservazione | Tutti i dati personali dell'utente vengono cancellati in modo definitivo dagli archivi entro 30 giorni dall'eliminazione dell'Account | RNF_L_1 |
| TF_SS_09 | Account con dati personali presenti, transazioni soggette ad obblighi di legge | Account cancellato con una o piu' transazioni di pagamento da conservare per obblighi di legge | I dati personali dell'Account vengono cancellati o dissociati entro 30 giorni, mentre le transazioni necessarie restano conservate senza collegamento personale agli archivi dell'utente | RNF_L_1 |

Totale frame: 28
