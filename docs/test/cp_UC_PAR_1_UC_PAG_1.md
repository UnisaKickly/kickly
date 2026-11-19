# Category partition - UC_PAR_1 Creazione Partita e UC_PAG_1 Pagamento quota partita

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/UC_PAR_1_CreazionePartita.md`, `docs/rad/uc/UC_PAG_1_PagamentoQuota.md` |
| **Requisiti** | RF_PAR_1, RF_PAR_2, RF_PAR_3, RF_PAG_1, RF_PAG_2, RF_PAG_3, RF_PAG_4; RNF_A_2, RNF_A_3, RNF_PRE_3; SDD DG3, DG2 |
| **Metodo testato** | Creazione: `GestionePartitaControl.richiediRiepilogo`, `GestionePartitaControl.finalizzaCreazione`, `PrenotazioneControl.verificaSlot`, `PrenotazioneControl.prenotaSlot` (SD_UC_PAR_1). RSVP: `GestionePartecipazioneControl` (metodo non ancora nei modelli). Annullamento: `GestionePartitaControl.gestisciAnnullamento` (azione di SCD_PAR_StatoPartita, classe decisa in DECISIONI_RAD D6). Pagamento: `GestioneTransazioniControl.richiediRiepilogo`, `GestioneTransazioniControl.avviaPagamento` (SD_UC_PAG_1) |
| **Autori** | Simona Sceral |
| **Revisori** | Mario Celzo, Renato Mancino |

Fonti degli esiti attesi: i due casi d'uso, RAD v2.9 §3.2 (RF_PAR_2, RF_PAR_3,
RF_PAG_1..4) e §3.3 (RNF), scenari SC_PAR_2 e SC_PAG_2 (RAD §3.4.1),
`docs/modelli/statechart_partita.puml`, `docs/modelli/DECISIONI_RAD.md` (D3, D5-D8) e
SDD v1.4 §1.2 (DG3 affidabilita' dell'RSVP, DG2 integrita' delle transazioni di pagamento). Dove il RAD non
dice l'esito, l'esito viene dalle decisioni dei PM D5-D8 (risposte alle domande
della sezione 4): nessun esito e' stato ipotizzato.

## 1. Parametri e condizioni dell'ambiente

| Parametro / condizione | Descrizione |
|---|---|
| Parametri partita | data, ora, campo, numero di partecipanti, tipologia, privacy (UC_PAR_1 passo 1) |
| Disponibilita' slot | stato dello slot del campo nel calendario della struttura (UC_PAR_1 passo 2) |
| Connessione alla conferma | raggiungibilita' del server alla conferma della creazione (UC_PAR_1 E1) |
| Posti disponibili | posti ancora liberi della partita al momento dell'RSVP (RF_PAR_2) |
| Risposta del giocatore | risposta RSVP gia' data o no dallo stesso giocatore (Partecipazione univoca) |
| Richieste concorrenti | numero di RSVP che arrivano insieme sull'ultimo posto (DG3, RNF_A_2) |
| Stato partita | Aperta, Completa, Confermata (statechart) |
| Tempo dell'annullamento | entro o oltre il tempo limite prestabilito (RF_PAR_3) |
| Stato quota | `Quota.statoVersamento`: non versata o versata |
| Termine versamento | `Quota.termineVersamento`: non scaduto o scaduto |
| Quote mancanti | la quota versata e' l'ultima mancante o no (UC_PAG_1 passo 7, A2) |
| Scelta al riepilogo | il Giocatore conferma o chiude il riepilogo (UC_PAG_1 passo 3, A1) |
| Esito del fornitore | positivo, negativo, non pervenuto (UC_PAG_1 passi 5-6, E1, E2) |
| Nuovo tentativo | il Giocatore ripete il pagamento dopo un esito non pervenuto (DG2) |
| Account del Gestore | account presso il fornitore collegato o no (DECISIONI_RAD D3) |

## 2. Categorie e scelte

### Parametri partita

| Categoria | Scelta | Vincolo |
|---|---|---|
| Completezza e validita' | tutti presenti e validi | `[property ParametriValidi]` |
| Completezza e validita' | parametri non validi o mancanti | `[error]` (esito da DECISIONI_RAD D7) |

### Disponibilita' slot

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato dello slot | libero | `[if ParametriValidi] [property SlotLibero]` |
| Stato dello slot | occupato | `[if ParametriValidi]` |

### Connessione alla conferma

| Categoria | Scelta | Vincolo |
|---|---|---|
| Server | raggiungibile | `[if SlotLibero]` |
| Server | non raggiungibile | `[error]` |

### Posti disponibili

| Categoria | Scelta | Vincolo |
|---|---|---|
| Posti liberi | piu' di uno | `[property PostiLiberi]` |
| Posti liberi | esattamente uno | `[single] [property UltimoPosto]` |
| Posti liberi | nessuno (capienza raggiunta) | `[property Piena]` |

### Tipo di risposta RSVP

| Categoria | Scelta | Vincolo |
|---|---|---|
| Risposta | conferma presenza | `[property Conferma]`; con `Piena` la combinazione e' un errore (un solo frame) |
| Risposta | ritiro presenza | `[single]` (valida anche con capienza raggiunta) |

### Risposta del giocatore

| Categoria | Scelta | Vincolo |
|---|---|---|
| Risposta precedente | nessuna | |
| Risposta precedente | presenza gia' confermata | `[single]` |

### Richieste concorrenti

| Categoria | Scelta | Vincolo |
|---|---|---|
| RSVP simultanei | uno | |
| RSVP simultanei | due sull'ultimo posto | `[if UltimoPosto] [single]` |

### Stato partita e tempo dell'annullamento

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato | Aperta | |
| Stato | Completa | `[property Completa]` |
| Stato | Confermata (tutte le quote versate) | `[single]` |
| Tempo | entro il limite (almeno 24 ore prima dell'inizio, D5) | |
| Tempo | oltre il limite (meno di 24 ore all'inizio) | `[error]` (esito da DECISIONI_RAD D5) |

### Stato quota e termine versamento

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato quota | non versata | `[if Completa] [property QuotaDaVersare]` |
| Stato quota | gia' versata | `[single]` (esito da DECISIONI_RAD D8) |
| Termine | non scaduto | `[if QuotaDaVersare] [property EntroTermine]` |
| Termine | scaduto, il Giocatore apre il pagamento | `[error]` |

### Scadenza del termine

Evento dello statechart `Completa --> Annullata : scadenza pagamento [quote mancanti]`.

| Categoria | Scelta | Vincolo |
|---|---|---|
| Alla scadenza | tutte le quote versate (partita gia' Confermata) | nessun effetto |
| Alla scadenza | quote mancanti | `[if Completa] [single]` |

### Quote mancanti

| Categoria | Scelta | Vincolo |
|---|---|---|
| Dopo il versamento | restano altre quote | `[if EntroTermine]` |
| Dopo il versamento | era l'ultima quota | `[if EntroTermine] [property UltimaQuota]` |

### Scelta al riepilogo

| Categoria | Scelta | Vincolo |
|---|---|---|
| Azione | conferma | `[if EntroTermine] [property Confermato]` |
| Azione | chiude il riepilogo | `[if EntroTermine] [single]` |

### Esito del fornitore e nuovo tentativo

| Categoria | Scelta | Vincolo |
|---|---|---|
| Esito | positivo | `[if Confermato]` |
| Esito | negativo (pagamento rifiutato) | `[error]` |
| Esito | non pervenuto | `[if Confermato] [property NonPervenuto]` |
| Nuovo tentativo | nessuno | |
| Nuovo tentativo | dopo esito non pervenuto | `[if NonPervenuto] [single]` |

### Account del Gestore

| Categoria | Scelta | Vincolo |
|---|---|---|
| Collegamento | collegato | `[if UltimaQuota]` |
| Collegamento | non collegato | `[if UltimaQuota] [single]` |

## 3. Test frame

L'esito atteso si prende dal caso d'uso (flusso principale, alternativo o di
errore), dagli RF/RNF e dai DG, mai dal comportamento del codice. Ogni frame avra'
un test con l'id in minuscolo nel nome (es. `tf_par_01_...`) nel ticket che
implementa il Control corrispondente.

### 3.1 Creazione partita (UC_PAR_1, RF_PAR_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_01 | parametri validi, slot libero, server raggiungibile | Giocatore autenticato nella schermata di creazione; campo con slot libero e tariffa base nota | Riepilogo con quota individuale = tariffa base del campo / numero di partecipanti; dopo la conferma la Partita e' registrata con stato "Aperta", lo slot e' prenotato e compare un messaggio di successo | Flusso principale, passi 1-5 |
| TF_PAR_02 | parametri validi, slot occupato | Slot gia' prenotato da un'altra partita | Il sistema avvisa l'utente e suggerisce orari/strutture alternative; scelta una nuova opzione libera si riprende dal passo 3 (riepilogo con i costi) | A1 (al passo 2) |
| TF_PAR_03 | parametri validi, slot libero, server non raggiungibile | Connessione interrotta prima della conferma | Il sistema notifica l'errore invitando a riprovare; la partita non viene creata e l'utente resta sulla schermata di creazione | E1 (al passo 4), exit condition on failure |
| TF_PAR_12 | parametri non validi o mancanti | Giocatore nella schermata di creazione; un campo obbligatorio vuoto, oppure data/ora nel passato, oppure numero di partecipanti inferiore ai giocatori in campo della tipologia (es. meno di 10 per il 5vs5) | Il sistema mostra un messaggio di errore sul campo da correggere; la partita non viene creata, la disponibilita' dello slot non viene verificata e l'utente resta sul modulo di creazione | DECISIONI_RAD D7, exit condition on failure |

### 3.2 Conferma o ritiro presenza (RF_PAR_2, SC_PAR_2, DG3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_04 | piu' posti liberi, nessuna risposta precedente, un RSVP | Partita "Aperta" con almeno 2 posti liberi | La risposta e' registrata, il contatore dei posti disponibili scende di 1 e il Giocatore compare tra i presenti confermati | RF_PAR_2, SC_PAR_2 |
| TF_PAR_05 | ultimo posto, un RSVP | Partita "Aperta" con 1 posto libero | La risposta e' registrata, il contatore va a 0 e la partita passa a "Completa" | RF_PAR_2, statechart (Aperta -> Completa) |
| TF_PAR_06 | nessun posto libero, conferma presenza | Partita "Completa" | La risposta non e' registrata e il contatore resta invariato: nessun overbooking. Il Giocatore vede il messaggio "Partita al completo" | SC_PAR_2 (verifica dei posti), DG3, RNF_A_2, DECISIONI_RAD D8 |
| TF_PAR_07 | ultimo posto, due RSVP simultanei | Partita "Aperta" con 1 posto libero; due Giocatori confermano nello stesso istante | Viene registrata una sola delle due conferme; il contatore non va sotto 0 e i partecipanti non superano il numero richiesto | DG3, RNF_A_2 |
| TF_PAR_08 | presenza gia' confermata | Il Giocatore ha gia' una Partecipazione confermata per la partita | Nessuna seconda Partecipazione e contatore invariato (associazione univoca Giocatore-Partita) | Tabella degli oggetti (Partecipazione), RF_PAR_2 |
| TF_PAR_09 | nessun posto libero, ritiro presenza | Partita "Completa", il Giocatore e' tra i confermati | Il posto si libera, il contatore sale di 1 e la partita torna "Aperta" | RF_PAR_2, statechart (Completa -> Aperta) |

### 3.3 Annullamento della partita (RF_PAR_3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_10 | stato Aperta, entro il limite | L'Organizzatore annulla una partita "Aperta" almeno 24 ore prima dell'inizio | La partita passa ad "Annullata", gli iscritti ricevono la notifica di cancellazione e lo slot presso la struttura viene sbloccato | RF_PAR_3, statechart (-> Annullata / gestisciAnnullamento()), DECISIONI_RAD D5, D6 |
| TF_PAR_11 | oltre il limite | Mancano meno di 24 ore all'inizio della partita; l'Organizzatore prova ad annullarla | Il comando di annullamento non e' disponibile; una richiesta di annullamento viene rifiutata con un messaggio di errore. La partita resta nel suo stato, nessuna notifica di cancellazione e lo slot resta prenotato | RF_PAR_3, DECISIONI_RAD D5 |

### 3.4 Pagamento della quota (UC_PAG_1, RF_PAG_1, RF_PAG_2, RF_PAG_4)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_01 | quota non versata, entro termine, conferma, esito positivo, restano altre quote | Partita "Completa"; mancano almeno 2 quote | Il riepilogo mostra importo, termine e quote mancanti; dopo l'esito positivo la quota e' "versata", le quote mancanti scendono di 1 e il Giocatore vede la conferma; la prenotazione non viene confermata e la partita resta "Completa" | Flusso principale passi 1-6, A2 (al passo 7), RF_PAG_4 |
| TF_PAG_02 | quota non versata, entro termine, conferma, esito positivo, ultima quota, Gestore collegato | Partita "Completa"; manca solo questa quota; Gestore con account presso il fornitore collegato | La quota e' "versata"; la prenotazione dello slot e' confermata e la partita passa a "Confermata"; l'importo del campo e' accreditato al Gestore al netto della commissione; Giocatori e Gestore ricevono la notifica di partita confermata | Flusso principale passi 6-8, RF_PAG_2, statechart (Completa -> Confermata) |
| TF_PAG_03 | entro termine, chiude il riepilogo | Riepilogo aperto | L'operazione e' annullata, il Giocatore torna alla pagina della partita e non viene registrato alcun versamento | A1 (al passo 3) |
| TF_PAG_04 | termine scaduto | Termine di versamento passato | Il comando di pagamento non e' disponibile e il sistema segnala che la partita e' stata annullata | A3 (al passo 1), RF_PAG_3 |
| TF_PAG_05 | conferma, esito negativo | Il fornitore rifiuta il pagamento | Il sistema segnala il mancato addebito; la quota resta non versata e si puo' riprovare entro il termine (si riprende dal passo 1) | E1 (al passo 5) |
| TF_PAG_06 | conferma, esito non pervenuto | La comunicazione con il fornitore si interrompe prima dell'esito | La quota resta non versata, nessun addebito registrato; il sistema invita il Giocatore a verificare prima di ripetere l'operazione | E2 (al passo 6), RNF_A_3 |
| TF_PAG_07 | quota gia' versata | Il Giocatore ha gia' versato la quota e riapre il pagamento | Nessun nuovo addebito (DG2): il comando di pagamento non e' disponibile e la pagina della partita mostra "Quota gia' versata" | Entry condition UC_PAG_1, DG2, DECISIONI_RAD D8 |
| TF_PAG_08 | esito non pervenuto, poi nuovo tentativo | Dopo TF_PAG_06 il fornitore aveva in realta' addebitato; il Giocatore ripete il pagamento | La quota risulta addebitata una sola volta (richiesta con riferimento idempotente) e passa a "versata" solo con l'esito positivo confermato | DG2, RNF_A_3 |

### 3.5 Rimborsi (RF_PAG_3, SC_PAG_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_09 | scadenza del termine con quote mancanti | Partita "Completa", alcune quote versate e almeno una no, il termine scade | La partita passa ad "Annullata" e le quote gia' versate vengono rimborsate ai Giocatori, che ricevono la notifica di annullamento | Exit condition on failure UC_PAG_1, SC_PAG_2, RF_PAG_3, RNF_PRE_3, statechart (Completa -> Annullata) |
| TF_PAG_10 | annullamento dell'organizzatore entro il limite, quote gia' versate | Partita "Completa" con alcune quote versate; l'Organizzatore la annulla | La partita passa ad "Annullata" e le quote gia' versate vengono rimborsate | RF_PAG_3, RF_PAR_3, RNF_PRE_3 |
| TF_PAG_12 | stato Confermata, annullamento dell'organizzatore entro il limite | Partita "Confermata" (tutte le quote versate); l'Organizzatore la annulla | La partita passa ad "Annullata", gli iscritti ricevono la notifica di cancellazione, lo slot viene sbloccato e tutte le quote versate vengono rimborsate | RF_PAR_3, RF_PAG_3, statechart (Confermata -> Annullata / gestisciAnnullamento()) |

### 3.6 Accredito con Gestore non collegato (RF_PAG_2, DECISIONI_RAD D3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_11 | ultima quota, Gestore non collegato | Come TF_PAG_02 ma il Gestore non ha collegato l'account presso il fornitore | La prenotazione e' confermata; l'accredito al Gestore resta "in attesa" e si completa al collegamento dell'account | DECISIONI_RAD D3, RF_PAG_2 |

Totale frame: 24 (TF_PAR_01..12, TF_PAG_01..12)

Copertura delle eccezioni dei casi d'uso: UC_PAR_1 A1 -> TF_PAR_02, E1 -> TF_PAR_03,
parametri non validi (D7) -> TF_PAR_12;
UC_PAG_1 A1 -> TF_PAG_03, A2 -> TF_PAG_01, A3 -> TF_PAG_04, E1 -> TF_PAG_05,
E2 -> TF_PAG_06 e TF_PAG_08.

## 4. Domande per i PM e risposte

Risposte dei PM (Renato Mancino, 19/11/2026). Le decisioni sono registrate in
`docs/modelli/DECISIONI_RAD.md`: nessun frame resta DA CONFERMARE.

1. Parametri non validi in UC_PAR_1 (data passata, numero di partecipanti incoerente con la tipologia, campi vuoti). **Risposta:** messaggio di errore sul campo e si resta sul modulo, come in UC_ACC_1 E2 e UC_LEG_1 E1. Frame TF_PAR_12 (DECISIONI_RAD D7).
2. "Tempo limite prestabilito" di RF_PAR_3. **Risposta:** 24 ore prima dell'inizio della partita. Oltre, il comando di annullamento non e' disponibile e la richiesta viene rifiutata; la partita resta invariata. Frame TF_PAR_11 (D5).
3. Messaggi per quota gia' versata (TF_PAG_07) e RSVP a capienza raggiunta (TF_PAR_06). **Risposta:** "Quota gia' versata" con comando di pagamento non disponibile; "Partita al completo" senza registrare la risposta (D8).
4. DG citati nel ticket. **Risposta:** confermati DG2 (Integrita' delle transazioni di pagamento, RNF_A_3) e DG3 (Affidabilita' dell'RSVP, RNF_A_2), cioe' i rank dell'SDD v1.4. Nel PDF v1.0 erano DG2 e DG3; dal 19/11 si usa il rank.
5. Proprietario di `gestisciAnnullamento()`. **Risposta:** `GestionePartitaControl` (D6). Il metodo di RSVP di `GestionePartecipazioneControl` resta da proporre nel piano del ticket che lo implementa (KCK-248).
6. RNF_PRE_3 (rimborso entro 5 giorni lavorativi nel 90% dei casi). **Risposta:** giusto lasciarlo fuori dagli esiti dei frame: e' una soglia statistica e si verifica con una misura a parte, non con un test unitario. I frame di rimborso verificano che il rimborso venga disposto.
