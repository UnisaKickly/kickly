# Creazione Partita

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_PAR_1 |
| **Versione** | 1.1.0 |
| **Data** | 01/11/2026 |
| **Autori** | Pietro Senatore |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Identificativo

UC_PAR_1

## Titolo

Creazione Partita

## Descrizione

Il sistema permette a un Giocatore (Organizzatore) di creare una nuova partita definendo data, ora, campo, numero partecipanti, tipologia e livello di privacy (pubblica o privata).

## Attori

- **Attore Principale**: Giocatore (Organizzatore)
- **Attori secondari**: N/A

## Entry Condition

Un Giocatore ha effettuato l'accesso alla piattaforma e si trova nella schermata di creazione di una nuova partita.

## Exit condition On success

La partita viene registrata a sistema con stato “Aperta” e lo slot orario viene prenotato in base alle disponibilità del calendario della struttura.

## Exit condition On failure

La partita non viene creata (es. campo non disponibile) e l'utente resta sulla schermata di creazione.

## Rilevanza/User Priority

Alta

## Frequenza stimata

50/giorno

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Giocatore: Inserisce i parametri richiesti (data, ora, campo, numero di partecipanti, tipologia e livello di privacy) e avvia la procedura di creazione.
2. Sistema: Verifica la disponibilità della struttura sportiva per lo slot orario indicato consultando il calendario automatico del campo.
3. Sistema: Calcola in automatico la quota individuale dividendo la tariffa base del campo per il numero di partecipanti, e mostra il riepilogo della partita con i costi.
4. Giocatore: Conferma la creazione della partita.
5. Sistema: Salva l'evento assegnando lo stato "Aperta", prenota lo slot e mostra un messaggio di successo all'utente

## FLUSSO DI EVENTI ALTERNATIVO

- **A1 (Al passo 2:)**: Slot non disponibile: il sistema avvisa l'utente e suggerisce orari/strutture alternative. L'utente sceglie una nuova opzione e si riprende dal passo 3.

## FLUSSO DI EVENTI DI ERRORE

- **E1 (Al passo 4:)**: Problema di connessione: il sistema non riesce a contattare il server per finalizzare la creazione. Il sistema notifica l'errore invitando a riprovare.

## RF collegati

### RF_PAR: PARTITE E RSVP

- **RF_PAR_1 | CreazionePartita | Alta**: Il sistema deve permettere a un Giocatore (Organizzatore) di creare una nuova partita definendo i parametri fondamentali: data, ora, struttura sportiva (campo), numero di partecipanti richiesti, privacy (pubblica/privata) e tipologia (es. 5vs5, 7vs7). Il costo della singola quota per giocatore verrà poi calcolato dal sistema seguendo la tariffa del campo.

## Requisiti speciali

N/A

## Tabella degli oggetti

- `Partita` (Entity): È il singolo evento sportivo creato dall’organizzatore
- `Campo` (Entity): È l’impianto sportivo dove si svolgerà. Fornisce la tariffa da dividere e la rappresentazione degli orari di disponibilità.
- `Prenotazione` (Entity): Collega una Partita a un Campo per un intervallo temporale. Conserva stato e scadenza del blocco, costo concordato, quota individuale (calcolata dai costi e dai partecipanti), commissione e netto destinato al gestore.
- `Partecipazione` (Entity): Associazione univoca (impedisce duplicati) tra un Giocatore e una Partita. Rappresenta risposta/stato, data della risposta, gol e assist della singola partita per ricavare le statistiche.
- `PrenotazioneControl` (Control): Gestisce la verifica della disponibilità del Campo, il blocco temporaneo, la conferma e la liberazione dello slot.
- `GestionePartitaControl` (Control): Coordina la creazione, il riepilogo e l'annullamento della partita.
- `GestionePartecipazioneControl` (Control): Realizza RF_PAR_2 e lo scenario SC_PAR_2: gestisce l'aggiornamento dinamico dei posti disponibili, impedendo il superamento della capienza.
- `FormCreazionePartita` (Boundary): Raccoglie i parametri della partita, permette la scelta del campo e mostra disponibilità e riepilogo dei costi
- `DettaglioPartita` (Boundary): Mostra informazioni, partecipanti e quote mancanti. Consente RSVP, annullamento, accesso al pagamento e condivisione, secondo i permessi
