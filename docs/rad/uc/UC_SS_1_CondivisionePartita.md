# Condivisione Partita

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_SS_1 |
| **Versione** | 1.0.0 |
| **Data** | 01/11/2026 |
| **Autori** | Antonio Tolino |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 01/11/2026 | 1.0.0 | Stesura del caso d'uso nel RAD v2.9 (sezione 3.4.2.6) | Antonio Tolino |
| 19/11/2026 | 1.0.0 | Trascrizione fedele in Markdown dal RAD v2.9 (KCK-193) | Gabriele Karol Vicinanza |

## Identificativo

UC_SS_1

## Titolo

Condivisione Partita

## Descrizione

Il sistema permette a un Giocatore di generare e condividere il link di una partita pubblica a cui è attualmente iscritto per invitare utenti esterni.

## Attori

- **Attore Principale**: Giocatore
- **Attori secondari**: N/A

## Entry Condition

Un utente registrato ha effettuato l'accesso alla piattaforma AND si trova nella schermata di dettaglio di una partita pubblica a cui è iscritto.

## Exit condition On success

Il link univoco della partita è stato generato e copiato/condiviso con successo all'esterno.

## Exit condition On failure

Il link non viene generato o la condivisione viene annullata dall'utente; l'utente resta sulla schermata della partita.

## Rilevanza/User Priority

Media

## Frequenza stimata

15/giorno

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Giocatore: Seleziona l'opzione "Condividi" dalla schermata di dettaglio della partita.
2. Sistema: Genera un URI/link univoco associato a quello specifico evento dal server.
3. Sistema: Invoca il menu di condivisione nativo del dispositivo mostrando le opzioni disponibili (es. Copia link, WhatsApp, Telegram).
4. Giocatore: Seleziona l'opzione desiderata dal menu del dispositivo.
5. Sistema: Registra l'azione e chiude il menù nativo. Se il Giocatore ha selezionato 'Copia link', mostra un messaggio di successo 'Link copiato!'. Se ha selezionato un'app di terze parti (es. WhatsApp), apre l'applicazione corrispondente.

## FLUSSO DI EVENTI ALTERNATIVO

- **A1 (Al passo 4:)**: Condivisione annullata: il Giocatore chiude il menu di condivisione senza selezionare alcuna opzione. Il sistema annulla l'operazione e l'utente resta sulla schermata di dettaglio della partita.

## FLUSSO DI EVENTI DI ERRORE

- **E1 (Al passo 2:)**: Problema di connessione: il sistema non riesce a contattare il server per generare il link. Il sistema notifica l'errore all'utente invitandolo a riprovare e si riprende dal passo 1.

## RF collegati

- **RF_SS_1 | CondivisionePartita | Media**: Il sistema deve permettere di generare un link univoco o un invito per una partita pubblica (ossia una singola partita non appartenente ad alcuna lega), condivisibile dagli utenti tramite app di messaggistica esterne (es. WhatsApp, Telegram).

## Requisiti speciali

- **RNF_IMP_1 | VincoliTecnologici | Alta**: Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging.

## Tabella degli oggetti

- `DispositivoRegistrato` (Entity): Conserva il riferimento di un dispositivo già utilizzato per accedere ad un Account, con primo e ultimo accesso. Permette di riconoscere accessi da nuovi dispositivi
- `GestioneCondivisioneControl` (Control): Realizza UC_SS_1: gestisce la logica di generazione del link univoco della partita e l'invocazione del menu di condivisione nativo.
- `SicurezzaAccessiControl` (Control): Realizza RF_SS_2 e lo scenario SC_SS_2:confronta il dispositivo di accesso con quelli registrati, registra il nuovo dispositivo e richiede l’invio dell’email di allerta.
- `CancellazioneAccountControl` (Control): Realizza RNF_L_1: coordina la richiesta di cancellazione dell’Account e il trattamento dei dati.
- `MenuCondivisione` (Boundary): Rappresenta l'interfaccia mostrata all'utente per selezionare l'app di messaggistica o copiare il link).(passi 3-5 di UC_SS_1).
- `ServizioEmail` (Boundary): Servizio di posta elettronica condiviso e utilizzato sia per il recupero della password sia per l'invio dell'email di allerta in caso di accesso da un nuovo dispositivo.
