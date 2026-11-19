# Category partition - UC_PAR_1 Creazione Partita e UC_PAG_1 Pagamento quota partita

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/UC_PAR_1_CreazionePartita.md`, `docs/rad/uc/UC_PAG_1_PagamentoQuota.md` |
| **Requisiti** | RF_PAR_1, RF_PAR_2, RF_PAR_3, RF_PAG_1, RF_PAG_2, RF_PAG_3, RF_PAG_4; RNF_A_2, RNF_A_3, RNF_PRE_3; SDD DG3, DG2 |
| **Metodo testato** | Creazione: `GestionePartitaControl.richiediRiepilogo`, `GestionePartitaControl.finalizzaCreazione`, `PrenotazioneControl.verificaSlot`, `PrenotazioneControl.prenotaSlot` (SD_UC_PAR_1). RSVP: `GestionePartecipazioneControl` (metodo non ancora nei modelli). Annullamento: `GestionePartitaControl.gestisciAnnullamento` (azione di SCD_PAR_StatoPartita, classe decisa in DECISIONI_RAD D6). Pagamento: `GestioneTransazioniControl.richiediRiepilogo`, `GestioneTransazioniControl.avviaPagamento` (SD_UC_PAG_1) |
| **Autori** | Simona Sceral |
| **Revisori** | Mario Celzo, Renato Mancino |

Metodo: category partition (Ostrand e Balcer, 1988). Il sistema e' diviso in
funzioni testabili in modo indipendente (F1-F6, sezione 1); per ogni funzione si
individuano parametri e condizioni dell'ambiente, categorie, scelte e vincoli.
Un test frame e' una combinazione valida con **una scelta per ogni categoria
della stessa funzione**: le categorie di funzioni diverse non si combinano. Una
scelta `[error]` o `[single]` produce un solo frame e non si combina con le altre.

Fonti degli esiti attesi: i due casi d'uso, RAD v2.9 §3.2 (RF_PAR_2, RF_PAR_3,
RF_PAG_1..4) e §3.3 (RNF), scenari SC_PAR_2 e SC_PAG_2 (RAD §3.4.1),
`docs/modelli/statechart_partita.puml`, `docs/modelli/DECISIONI_RAD.md` (D3, D5-D8) e
SDD v1.4 §1.2 (DG3 affidabilita' dell'RSVP, DG2 integrita' delle transazioni di pagamento). Dove il RAD non
dice l'esito, l'esito viene dalle decisioni dei PM D5-D8 (risposte alle domande
della sezione 4): nessun esito e' stato ipotizzato.

## 1. Funzioni, parametri e condizioni dell'ambiente

| Funzione | Control | Requisiti | Parametri | Condizioni dell'ambiente |
|---|---|---|---|---|
| F1 Creazione partita | `GestionePartitaControl`, `PrenotazioneControl` | UC_PAR_1, RF_PAR_1, D7 | data, ora, campo, numero di partecipanti, tipologia, privacy | stato dello slot nel calendario della struttura; connessione alla conferma |
| F2 Conferma o ritiro presenza (RSVP) | `GestionePartecipazioneControl` | RF_PAR_2, SC_PAR_2, RNF_A_2, DG3, D8 | richiesta (conferma o ritiro) | posti liberi; risposta precedente del Giocatore; RSVP simultanei |
| F3 Annullamento dell'Organizzatore | `GestionePartitaControl` (`gestisciAnnullamento`, D6) | RF_PAR_3, RF_PAG_3, D5 | nessuno (richiesta di annullamento) | stato della partita e quote versate; tempo mancante all'inizio |
| F4 Pagamento della quota | `GestioneTransazioniControl` | UC_PAG_1, RF_PAG_1, RF_PAG_4, RNF_A_3, DG2, D8 | scelta al riepilogo; nuovo tentativo | stato della quota; termine di versamento; esito del fornitore |
| F5 Ultima quota: conferma e accredito | `GestioneTransazioniControl` | UC_PAG_1 passi 7-8, RF_PAG_2, D3 | nessuno (versamento dell'ultima quota) | account del Gestore presso il fornitore |
| F6 Scadenza del termine di versamento | `GestionePartitaControl` (D6), `GestioneTransazioniControl` | RF_PAG_3, SC_PAG_2, statechart | nessuno (evento di scadenza) | quote ancora mancanti alla scadenza |

## 2. Categorie e scelte

Vincoli: `[error]` scelta che porta a un errore o a un'operazione rifiutata (un
solo frame); `[single]` caso speciale o limite da provare una sola volta;
`[property X]` / `[if X]` solo dove servono a escludere combinazioni
contraddittorie.

### F1 Creazione partita

| Categoria | Scelta | Vincolo |
|---|---|---|
| Parametri della partita | presenti e validi | |
| Parametri della partita | mancanti o non validi (D7) | `[error]` |
| Slot nel calendario | libero | |
| Slot nel calendario | occupato (A1) | |
| Connessione alla conferma | raggiungibile | |
| Connessione alla conferma | non raggiungibile (E1) | `[error]` |

### F2 Conferma o ritiro presenza (RSVP)

| Categoria | Scelta | Vincolo |
|---|---|---|
| Posti liberi | piu' di uno | |
| Posti liberi | esattamente uno (valore limite) | `[property UltimoPosto]` |
| Posti liberi | nessuno (partita "Completa") | |
| Richiesta | conferma presenza | |
| Richiesta | ritiro presenza di un Giocatore confermato | `[single]` |
| Risposta precedente | nessuna | |
| Risposta precedente | presenza gia' confermata | `[single]` |
| RSVP simultanei | uno | |
| RSVP simultanei | due sull'ultimo posto | `[if UltimoPosto]` |

### F3 Annullamento dell'Organizzatore

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato della partita | "Aperta" | |
| Stato della partita | "Completa" con alcune quote gia' versate | |
| Stato della partita | "Confermata" (tutte le quote versate) | `[single]` |
| Tempo all'inizio | almeno 24 ore (entro il limite, D5) | |
| Tempo all'inizio | meno di 24 ore (oltre il limite, D5) | `[error]` |

### F4 Pagamento della quota

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato della quota | non versata | |
| Stato della quota | gia' versata (D8) | `[single]` |
| Termine di versamento | non scaduto | |
| Termine di versamento | scaduto (A3) | `[error]` |
| Scelta al riepilogo | conferma | |
| Scelta al riepilogo | chiude il riepilogo (A1) | `[single]` |
| Esito del fornitore | positivo | |
| Esito del fornitore | negativo (E1) | `[error]` |
| Esito del fornitore | non pervenuto (E2) | `[property NonPervenuto]` |
| Nuovo tentativo | nessuno | |
| Nuovo tentativo | dopo un esito non pervenuto | `[if NonPervenuto] [single]` |

Nota: in F4 la quota versata non e' l'ultima mancante; il caso dell'ultima quota
e' la funzione F5.

### F5 Ultima quota: conferma della prenotazione e accredito

| Categoria | Scelta | Vincolo |
|---|---|---|
| Account del Gestore presso il fornitore | collegato | |
| Account del Gestore presso il fornitore | non collegato (D3) | `[single]` |

### F6 Scadenza del termine di versamento

Evento dello statechart `Completa --> Annullata : scadenza pagamento [quote mancanti]`.

| Categoria | Scelta | Vincolo |
|---|---|---|
| Quote alla scadenza | almeno una mancante | |
| Quote alla scadenza | tutte versate (partita gia' "Confermata") | `[single]` |

## 3. Test frame

L'esito atteso si prende dal caso d'uso (flusso principale, alternativo o di
errore), dagli RF/RNF, dai DG e dalle decisioni dei PM, mai dal comportamento del
codice. Ogni frame avra' un test con l'id in minuscolo nel nome (es.
`tf_par_01_...`) nel ticket che implementa il Control corrispondente. Gli id
restano quelli della prima versione (le decisioni D5-D8 li citano), quindi
dentro una funzione non sono sempre consecutivi.

### 3.1 F1 Creazione partita (UC_PAR_1, RF_PAR_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_01 | parametri validi, slot libero, server raggiungibile | Giocatore autenticato nella schermata di creazione; campo con slot libero e tariffa base nota | Riepilogo con quota individuale = tariffa base del campo / numero di partecipanti; dopo la conferma la Partita e' registrata con stato "Aperta", lo slot e' prenotato e compare un messaggio di successo | Flusso principale, passi 1-5 |
| TF_PAR_02 | parametri validi, slot occupato | Slot gia' prenotato da un'altra partita | Il sistema avvisa l'utente e suggerisce orari/strutture alternative; scelta una nuova opzione libera si riprende dal passo 3 (riepilogo con i costi) | A1 (al passo 2) |
| TF_PAR_03 | parametri validi, slot libero, server non raggiungibile | Connessione interrotta prima della conferma | Il sistema notifica l'errore invitando a riprovare; la partita non viene creata e l'utente resta sulla schermata di creazione | E1 (al passo 4), exit condition on failure |
| TF_PAR_12 | parametri non validi o mancanti | Giocatore nella schermata di creazione; un campo obbligatorio vuoto, oppure data/ora nel passato, oppure numero di partecipanti inferiore ai giocatori in campo della tipologia (es. meno di 10 per il 5vs5) | Il sistema mostra un messaggio di errore sul campo da correggere; la partita non viene creata, la disponibilita' dello slot non viene verificata e l'utente resta sul modulo di creazione | DECISIONI_RAD D7, exit condition on failure |

### 3.2 F2 Conferma o ritiro presenza (RF_PAR_2, SC_PAR_2, DG3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_04 | piu' posti liberi, nessuna risposta precedente, un RSVP | Partita "Aperta" con almeno 2 posti liberi | La risposta e' registrata, il contatore dei posti disponibili scende di 1 e il Giocatore compare tra i presenti confermati | RF_PAR_2, SC_PAR_2 |
| TF_PAR_05 | ultimo posto, un RSVP | Partita "Aperta" con 1 posto libero | La risposta e' registrata, il contatore va a 0 e la partita passa a "Completa" | RF_PAR_2, statechart (Aperta -> Completa) |
| TF_PAR_06 | nessun posto libero, conferma presenza | Partita "Completa" | La risposta non e' registrata e il contatore resta invariato: nessun overbooking. Il Giocatore vede il messaggio "Partita al completo" | SC_PAR_2 (verifica dei posti), DG3, RNF_A_2, DECISIONI_RAD D8 |
| TF_PAR_07 | ultimo posto, due RSVP simultanei | Partita "Aperta" con 1 posto libero; due Giocatori confermano nello stesso istante | Viene registrata una sola delle due conferme; il contatore non va sotto 0 e i partecipanti non superano il numero richiesto | DG3, RNF_A_2 |
| TF_PAR_08 | presenza gia' confermata | Il Giocatore ha gia' una Partecipazione confermata per la partita | Nessuna seconda Partecipazione e contatore invariato (associazione univoca Giocatore-Partita) | Tabella degli oggetti (Partecipazione), RF_PAR_2 |
| TF_PAR_09 | nessun posto libero, ritiro presenza | Partita "Completa", il Giocatore e' tra i confermati | Il posto si libera, il contatore sale di 1 e la partita torna "Aperta" | RF_PAR_2, statechart (Completa -> Aperta) |

### 3.3 F3 Annullamento dell'Organizzatore (RF_PAR_3, RF_PAG_3, D5, D6)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAR_10 | stato Aperta, entro il limite | L'Organizzatore annulla una partita "Aperta" almeno 24 ore prima dell'inizio | La partita passa ad "Annullata", gli iscritti ricevono la notifica di cancellazione e lo slot presso la struttura viene sbloccato | RF_PAR_3, statechart (-> Annullata / gestisciAnnullamento()), DECISIONI_RAD D5, D6 |
| TF_PAG_10 | annullamento dell'organizzatore entro il limite, quote gia' versate | Partita "Completa" con alcune quote versate; l'Organizzatore la annulla | La partita passa ad "Annullata" e le quote gia' versate vengono rimborsate | RF_PAG_3, RF_PAR_3, RNF_PRE_3 |
| TF_PAG_12 | stato Confermata, annullamento dell'organizzatore entro il limite | Partita "Confermata" (tutte le quote versate); l'Organizzatore la annulla | La partita passa ad "Annullata", gli iscritti ricevono la notifica di cancellazione, lo slot viene sbloccato e tutte le quote versate vengono rimborsate | RF_PAR_3, RF_PAG_3, statechart (Confermata -> Annullata / gestisciAnnullamento()) |
| TF_PAR_11 | oltre il limite | Mancano meno di 24 ore all'inizio della partita; l'Organizzatore prova ad annullarla | Il comando di annullamento non e' disponibile; una richiesta di annullamento viene rifiutata con un messaggio di errore. La partita resta nel suo stato, nessuna notifica di cancellazione e lo slot resta prenotato | RF_PAR_3, DECISIONI_RAD D5 |

### 3.4 F4 Pagamento della quota (UC_PAG_1, RF_PAG_1, RF_PAG_4, DG2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_01 | quota non versata, entro termine, conferma, esito positivo, restano altre quote | Partita "Completa"; mancano almeno 2 quote | Il riepilogo mostra importo, termine e quote mancanti; dopo l'esito positivo la quota e' "versata", le quote mancanti scendono di 1 e il Giocatore vede la conferma; la prenotazione non viene confermata e la partita resta "Completa" | Flusso principale passi 1-6, A2 (al passo 7), RF_PAG_4 |
| TF_PAG_03 | entro termine, chiude il riepilogo | Riepilogo aperto | L'operazione e' annullata, il Giocatore torna alla pagina della partita e non viene registrato alcun versamento | A1 (al passo 3) |
| TF_PAG_04 | termine scaduto | Termine di versamento passato | Il comando di pagamento non e' disponibile e il sistema segnala che la partita e' stata annullata | A3 (al passo 1), RF_PAG_3 |
| TF_PAG_05 | conferma, esito negativo | Il fornitore rifiuta il pagamento | Il sistema segnala il mancato addebito; la quota resta non versata e si puo' riprovare entro il termine (si riprende dal passo 1) | E1 (al passo 5) |
| TF_PAG_06 | conferma, esito non pervenuto | La comunicazione con il fornitore si interrompe prima dell'esito | La quota resta non versata, nessun addebito registrato; il sistema invita il Giocatore a verificare prima di ripetere l'operazione | E2 (al passo 6), RNF_A_3 |
| TF_PAG_07 | quota gia' versata | Il Giocatore ha gia' versato la quota e riapre il pagamento | Nessun nuovo addebito (DG2): il comando di pagamento non e' disponibile e la pagina della partita mostra "Quota gia' versata" | Entry condition UC_PAG_1, DG2, DECISIONI_RAD D8 |
| TF_PAG_08 | esito non pervenuto, poi nuovo tentativo | Dopo TF_PAG_06 il fornitore aveva in realta' addebitato; il Giocatore ripete il pagamento | La quota risulta addebitata una sola volta (richiesta con riferimento idempotente) e passa a "versata" solo con l'esito positivo confermato | DG2, RNF_A_3 |

### 3.5 F5 Ultima quota: conferma e accredito (UC_PAG_1 passi 7-8, RF_PAG_2, D3)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_02 | quota non versata, entro termine, conferma, esito positivo, ultima quota, Gestore collegato | Partita "Completa"; manca solo questa quota; Gestore con account presso il fornitore collegato | La quota e' "versata"; la prenotazione dello slot e' confermata e la partita passa a "Confermata"; l'importo del campo e' accreditato al Gestore al netto della commissione; Giocatori e Gestore ricevono la notifica di partita confermata | Flusso principale passi 6-8, RF_PAG_2, statechart (Completa -> Confermata) |
| TF_PAG_11 | ultima quota, Gestore non collegato | Come TF_PAG_02 ma il Gestore non ha collegato l'account presso il fornitore | La prenotazione e' confermata; l'accredito al Gestore resta "in attesa" e si completa al collegamento dell'account | DECISIONI_RAD D3, RF_PAG_2 |

### 3.6 F6 Scadenza del termine (RF_PAG_3, SC_PAG_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_PAG_09 | scadenza del termine con quote mancanti | Partita "Completa", alcune quote versate e almeno una no, il termine scade | La partita passa ad "Annullata" e le quote gia' versate vengono rimborsate ai Giocatori, che ricevono la notifica di annullamento | Exit condition on failure UC_PAG_1, SC_PAG_2, RF_PAG_3, RNF_PRE_3, statechart (Completa -> Annullata) |
| TF_PAG_13 | tutte le quote versate alla scadenza | Partita gia' "Confermata" (tutte le quote versate) quando scade il termine | Nessun effetto: la partita resta "Confermata", nessun annullamento e nessun rimborso | Statechart (la transizione per scadenza esiste solo da "Completa" con la guardia [quote mancanti]) |

Totale frame: 25 (TF_PAR_01..12, TF_PAG_01..13)

Copertura delle eccezioni dei casi d'uso: UC_PAR_1 A1 -> TF_PAR_02, E1 -> TF_PAR_03,
parametri non validi (D7) -> TF_PAR_12; UC_PAG_1 A1 -> TF_PAG_03, A2 -> TF_PAG_01,
A3 -> TF_PAG_04, E1 -> TF_PAG_05, E2 -> TF_PAG_06 e TF_PAG_08.

## 4. Domande per i PM e risposte

Risposte dei PM (Renato Mancino, 19/11/2026). Le decisioni sono registrate in
`docs/modelli/DECISIONI_RAD.md`: nessun frame resta DA CONFERMARE.

1. Parametri non validi in UC_PAR_1 (data passata, numero di partecipanti incoerente con la tipologia, campi vuoti). **Risposta:** messaggio di errore sul campo e si resta sul modulo, come in UC_ACC_1 E2 e UC_LEG_1 E1. Frame TF_PAR_12 (DECISIONI_RAD D7).
2. "Tempo limite prestabilito" di RF_PAR_3. **Risposta:** 24 ore prima dell'inizio della partita. Oltre, il comando di annullamento non e' disponibile e la richiesta viene rifiutata; la partita resta invariata. Frame TF_PAR_11 (D5).
3. Messaggi per quota gia' versata (TF_PAG_07) e RSVP a capienza raggiunta (TF_PAR_06). **Risposta:** "Quota gia' versata" con comando di pagamento non disponibile; "Partita al completo" senza registrare la risposta (D8).
4. DG citati nel ticket. **Risposta:** confermati DG2 (Integrita' delle transazioni di pagamento, RNF_A_3) e DG3 (Affidabilita' dell'RSVP, RNF_A_2), cioe' i rank dell'SDD v1.4. Nel PDF v1.0 erano DG2 e DG3; dal 19/11 si usa il rank.
5. Proprietario di `gestisciAnnullamento()`. **Risposta:** `GestionePartitaControl` (D6). Il metodo di RSVP di `GestionePartecipazioneControl` resta da proporre nel piano del ticket che lo implementa (KCK-248).
6. RNF_PRE_3 (rimborso entro 5 giorni lavorativi nel 90% dei casi). **Risposta:** giusto lasciarlo fuori dagli esiti dei frame: e' una soglia statistica e si verifica con una misura a parte, non con un test unitario. I frame di rimborso verificano che il rimborso venga disposto.
