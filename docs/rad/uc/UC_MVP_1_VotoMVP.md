# Assegnazione voto MVP della partita

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_MVP_1 |
| **Versione** | 1.0.0 |
| **Data** | 01/11/2026 |
| **Autori** | Giuseppe Sarlo |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 01/11/2026 | 1.0.0 | Stesura del caso d'uso nel RAD v2.9 (sezione 3.4.2.4) | Giuseppe Sarlo |
| 19/11/2026 | 1.0.0 | Trascrizione fedele in Markdown dal RAD v2.9 (KCK-193) | Gabriele Karol Vicinanza |

## Identificativo

UC_MVP_1

## Titolo

Assegnazione voto MVP della partita

## Descrizione

Lo use case permette a un giocatore di esprimere il proprio voto per eleggere il Migliore in Campo (MVP) al termine di una partita disputata.

## Attori

- **Attore Principale**: Giocatore
- **Attori secondari**: N/A

## Entry Condition

Un Giocatore ha effettuato l'accesso alla piattaforma AND la partita risulta nello stato “Conclusa”.

## Exit condition On success

Il voto è stato registrato con successo e le statistiche del giocatore votato sono aggiornate.

## Exit condition On failure

Il voto non è stato registrato e il giocatore viene avvisato dell'errore.

## Rilevanza/User Priority

Alta

## Frequenza stimata

20/giorno

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Giocatore: Accede alla sezione di dettaglio della partita conclusa e richiede di poter votare l'MVP.
2. Sistema: Il sistema visualizza l'elenco dei giocatori partecipanti alla partita fornendo il comando per esprimere il voto.
3. Giocatore: Seleziona il giocatore che desidera votare e conferma la scelta.
4. Sistema: Il sistema verifica che il giocatore non abbia già espresso un voto per la stessa partita e che la connessione sia attiva.
5. Sistema: Il sistema salva la preferenza e aggiorna i dati statistici dell'utente votato.
6. Sistema: Il sistema visualizza un messaggio di successo confermando la registrazione del voto.

## FLUSSO DI EVENTI ALTERNATIVO

- **3.1**: Sistema: Se il sistema rileva che il giocatore ha già espresso il proprio voto per quella specifica partita, blocca l'operazione e mostra un messaggio di avviso.

## FLUSSO DI EVENTI DI ERRORE

- **1.1**: Sistema: Se si verifica un problema di connessione durante l’accesso alla sezione di dettaglio della partita, il sistema notifica l'errore all'utente invitandolo a riprovare più tardi.
- **4.1**: Sistema: Se si verifica un problema di connessione durante la conferma, il sistema notifica l'errore all'utente invitandolo a riprovare più tardi.

## RF collegati

- **RF_POS_1 | VotoMVP | Alta**: Il sistema deve permettere a un giocatore di votare il miglior giocatore in campo (MVP) al termine di una partita conclusa.
- **RF_POS_2 | StatisticaGiocatori | Media**: Il sistema deve permettere all'utente di consultare la classifica dei giocatori con più titoli MVP e le relative statistiche (goal e assist).

## Requisiti speciali

- **RNF_A_1 | ConsistenzaStatistichePlayerCard | Alta**: ll sistema deve aggiornare le statistiche della Player Card (gol, assist, presenze, voti MVP) entro 1 minuto dalla chiusura di ciascun incontro (vincolo di progetto, per garantire una percezione di aggiornamento in tempo reale), conservarle senza perdite in caso di riavvio o malfunzionamento e mostrare valori coincidenti con lo storico degli incontri.
- **RNF_PRE_2 | TempoRegistrazioneVotoMVP | Alta**: Il sistema deve elaborare la registrazione del voto MVP entro un tempo massimo di 10 secondi per non bloccare l’interfaccia (riferimento: soglia di attenzione dell’utente in un’interazione — Nielsen, “Usability Engineering”, 1993: oltre i 10 secondi l’utente perde il focus sul compito).
- **RNF_IMP_1 | VincoliTecnologici | Alta**: Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging.

## Tabella degli oggetti

- `VotazioneMVP` (Entity): Collegata alla Partita (copre partite di lega ed esterne). Rappresenta stato, eventuale scadenza, preferenze votante-votato (con il vincolo di un solo voto per giocatore nella stessa votazione) e identifica il vincitore.
- `Notifica` (Entity): Contiene i dati di una notifica in-app: destinatario, tipo, messaggio, data (timestamp) e stato di lettura.
- `VotoMVPControl` (Control): Realizza lo UC_MVP_1: raccoglie il voto, verifica che non sia duplicato per la stessa partita, aggiorna le statistiche e determina il vincitore.
- `ClassificaControl` (Control): Realizza RF_POS_2: calcola e mostra la classifica dei giocatori distinguendo i voti ricevuti e i titoli MVP vinti, oltre a gol e assist.
- `NotificaControl` (Control): Realizza RF_NOT_1 e lo scenario SC_NOT_1: gestisce l'invio delle notifiche in-app, la loro consultazione e l'aggiornamento dello stato di lettura.
- `PreferenzeNotificheControl` (Control): Realizza RF_NOT_2: gestisce l'attivazione, disattivazione e personalizzazione delle notifiche, aggiornando le preferenze salvate nell'Account.
- `FormVotoMVP` (Boundary): Mostra l’elenco dei giocatori della partita conclusa e permette di esprimere il voto MVP (passi 1-3 di UC_MVP_1).
- `VistaClassifica` (Boundary): Mostra la classifica dei giocatori in base a voti MVP, gol e assist (RF_POS_2).
- `PannelloNotifiche` (Boundary): Mostra le notifiche in-app ricevute e permette di aprirle (SC_NOT_1).
- `ImpostazioniNotifiche` (Boundary): Permette di attivare, disattivare o personalizzare le notifiche (RF_NOT_2).
