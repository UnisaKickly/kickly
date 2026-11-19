# Creazione Lega e Invito Membri

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_LEG_1 |
| **Versione** | 1.1.0 |
| **Data** | 01/11/2026 |
| **Autori** | Gabriele Karol Vicinanza |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Identificativo

UC_LEG_1

## Titolo

Creazione Lega e Invito Membri

## Descrizione

Il sistema permette a un Giocatore di creare una nuova lega (definendone nome, formato e livello di privacy) e di generare un codice d'invito univoco per consentire ad altri utenti di unirsi alla lega.

## Attori

- **Attore Principale**: Giocatore (Amministratore della lega)
- **Attori secondari**: Giocatore (Membro)

## Entry Condition

Il Giocatore ha effettuato l'accesso alla piattaforma Kickly e si trova nella sezione "Leghe".

## Exit condition On success

La nuova lega viene registrata a sistema, l'utente ne diventa Amministratore e il secondo Giocatore si unisce con successo alla lega tramite il codice di invito.

## Exit condition On failure

La creazione della lega o la procedura d'invito viene annullata o fallisce; l'utente rimane nella schermata delle leghe senza modifiche ai dati persi.

## Rilevanza/User Priority

Alta

## Frequenza stimata

5/settimana

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Giocatore: Seleziona l'opzione "Crea Nuova Lega" dalla sezione "Leghe" dell'applicazione.
2. Sistema: Mostra il modulo di creazione richiedendo il nome della lega, la tipologia di match (es. 5vs5, 6vs6, 7vs7, 8vs8, 9vs9, 10vs10, 11vs11) e il livello di privacy (Pubblica/Privata).
3. Giocatore: Inserisce i dati richiesti (es. "Champions Giovedì", "5vs5", "Privata") e invia il modulo.
4. Sistema: Valida i dati, registra la lega a sistema, assegna all'utente il ruolo di Amministratore della lega, genera un codice d'invito univoco e mostra la dashboard della lega.
5. Giocatore: Seleziona l'opzione "Condividi Invito" e invia il codice univoco generato a un altro Giocatore.
6. Giocatore (Membro): Accede alla sezione "Leghe", inserisce il codice d'invito ricevuto e conferma l'adesione.
7. Sistema: Verifica la validità del codice, aggiunge il Giocatore elenco membri della lega e aggiorna la dashboard della lega.

## FLUSSO DI EVENTI ALTERNATIVO

- **A1 (Al passo 3:)**: Lega Pubblica: Il Giocatore imposta il livello di privacy su "Pubblica". Il sistema rende la lega visibile nella ricerca globale e consente l'accesso diretto ai giocatori anche senza codice d'invito.

## FLUSSO DI EVENTI DI ERRORE

- **E1 (Al passo 4:)**: Dati non validi o nome duplicato: Il sistema rileva un errore nei dati inseriti o un nome lega già in uso, mostra un messaggio di errore ed evidenzia i campi da correggere rimanendo al passo 2.
- **E2 (Al passo 7:)**: Codice d'invito errato o scaduto: Il sistema non trova alcuna lega associata al codice inserito, notifica l'errore al Giocatore richiedendo un nuovo inserimento e interrompe la procedura di unione.

## RF collegati

- **RF_LEG_1 | CreazioneEGestioneLega | Alta**: Il sistema deve permettere a un Giocatore di creare una nuova lega specificandone il nome, la tipologia di partita ( 5vs5, 6v6, 7v7, 8vs8, 9vs9, 10v10, 11vs11 ) e livello di privacy (pubblica o privata), assumendo il ruolo di amministratore della lega e potendone modificare i dettagli
- **RF_LEG_2 | GeneratoreEGestioneInviti | Alta**: Il sistema deve permettere all’amministratore della lega di generare e condividere un codice o link di invito, e deve permettere gli altri Giocatori di unirsi alla lega tramite l’inserimento manuale del codice o l’accesso diretto via link

## Requisiti speciali

- **RNF_U_2 | UnioneALega | Alta**: Il sistema deve permettere a un Giocatore autenticato di unirsi a una lega, privata o pubblica, inserendo il codice d’invito o accedendo tramite link di condivisione (correlato a RF_LEG_2), con un massimo di 3 interazioni e senza richiedere di reinserire dati già forniti.
- **RNF_S_1 | EstensibilitàLegheEInviti | Bassa**: Il modulo “Leghe e inviti” deve essere progettato in modo modulare, così da permettere di aggiungere una nuova tipologia di lega (es. torneo a eliminazione diretta, campionato a gironi) o un nuovo canale di condivisione degli inviti senza modificare la logica di gestione dei membri
- **RNF_IMP_1 | VincoliTecnologici | Alta**: Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging.

## Tabella degli oggetti

- `Lega` (Entity): Contiene i dati relativi a una competizione (nome, tipologia di match, livello di privacy). Assorbe il codice univoco di invito e la relativa scadenza. Membri e amministratori sono gestiti tramite associazione con Giocatore
- `GestioneLegaControl` (Control): Realizza UC_LEG_1 (passi 1-4): gestisce validazione, controllo nomi duplicati, registrazione lega e nomina Amministratore. Esteso a: modifica dei dettagli, generazione invito, gestione membri/admin e consultazione dashboard.
- `GestioneAdesioneControl` (Control): Realizza UC_LEG_1 (passi 5-7): gestisce l'ingresso tramite codice, ingresso tramite link, e l'accesso diretto per le leghe pubbliche, aggiungendo i nuovi membri.
- `FormLega` (Boundary): Interfaccia riutilizzata sia per la creazione che per la modifica dei dettagli di una lega (nome, formato, privacy).
- `FormAdesioneLega` (Boundary): Interfaccia della sezione "Leghe" in cui l'utente invitato inserisce e conferma il codice d’invito ricevuto.
- `DashboardLega` (Boundary): Schermata di riepilogo della lega. Mostra codice d'invito, membri aggiornati, prossime partite, storico incontri, statistiche e i comandi riservati agli amministratori.
- `VistaLeghe` (Boundary): Interfaccia che mostra l'elenco delle proprie leghe a cui si è iscritti e permette la ricerca delle leghe pubbliche.
