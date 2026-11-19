# Pagamento quota partita (numero di persone raggiunte)

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_PAG_1 |
| **Versione** | 1.0.0 |
| **Data** | 03/11/2026 |
| **Autori** | Francesco Nuzzolo |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 03/11/2026 | 1.0.0 | Stesura del caso d'uso nel RAD v2.9 (sezione 3.4.2.5) | Francesco Nuzzolo |
| 19/11/2026 | 1.0.0 | Trascrizione fedele in Markdown dal RAD v2.9 (KCK-193) | Gabriele Karol Vicinanza |

## Identificativo

UC_PAG_1

## Titolo

Pagamento quota partita (numero di persone raggiunte)

## Descrizione

Il sistema permette a un Giocatore iscritto a una partita che ha raggiunto il numero di partecipanti previsto di versare la propria quota entro il termine indicato; al completamento di tutte le quote conferma la prenotazione dello slot e dispone l’accredito al Gestore del Campo.

## Attori

- **Attore Principale**: Giocatore
- **Attori secondari**: Gestore del Campo

## Entry Condition

Il Giocatore ha effettuato l’accesso alla piattaforma, risulta iscritto a una partita nello stato “Completa”, non ha ancora versato la propria quota e il termine per il versamento non è scaduto.

## Exit condition On success

La quota del Giocatore risulta versata; se è l’ultima mancante, la prenotazione dello slot viene confermata e l’importo del campo accreditato al Gestore al netto della commissione.

## Exit condition On failure

La quota non risulta versata e il Giocatore resta sulla schermata della partita; alla scadenza del termine la partita passa allo stato “Annullata” e le quote già versate vengono rimborsate.

## Rilevanza/User Priority

Alta

## Frequenza stimata

600/giorno

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Giocatore: Accede alla pagina della partita e seleziona il comando per versare la propria quota.
2. Sistema: Mostra il riepilogo con l’importo della quota, il termine entro cui versarla e il numero di quote ancora mancanti.
3. Giocatore: Conferma di voler procedere al pagamento.
4. Sistema: Inoltra la richiesta di pagamento al fornitore esterno del servizio di pagamento.
5. Giocatore: Completa il pagamento presso il fornitore del servizio.
6. Sistema: Riceve l’esito positivo, registra la quota come versata, aggiorna il numero di quote mancanti e mostra al Giocatore la conferma dell’avvenuto versamento.
7. Sistema: Verifica che tutte le quote della partita risultino versate e conferma la prenotazione dello slot presso la struttura.
8. Sistema: Dispone l’accredito dell’importo del campo al Gestore, al netto della commissione trattenuta dalla piattaforma, e notifica ai Giocatori e al Gestore che la partita è confermata.

## FLUSSO DI EVENTI ALTERNATIVO

- **A1 (Al passo 3:)**: Annullamento dell’operazione: il Giocatore chiude il riepilogo senza procedere. Il sistema annulla l’operazione e lo riporta alla pagina della partita, senza registrare alcun versamento.
- **A2 (Al passo 7:)**: Quote ancora mancanti: il sistema rileva che non tutte le quote risultano versate. La prenotazione non viene confermata e il caso d’uso termina al passo 6; i passi 7 e 8 si eseguono al versamento dell’ultima quota.
- **A3 (Al passo 1:)**: Termine scaduto: il sistema rileva che il termine per il versamento è scaduto. Il comando di pagamento non è disponibile e il sistema segnala al Giocatore che la partita è stata annullata (cfr. RF_PAG_3).

## FLUSSO DI EVENTI DI ERRORE

- **E1 (Al passo 5:)**: Pagamento rifiutato: il fornitore del servizio restituisce un esito negativo. Il sistema segnala il mancato addebito, lascia la quota nello stato non versato e resta in attesa di un nuovo tentativo entro il termine; si riprende dal passo 1.
- **E2 (Al passo 6:)**: Esito non pervenuto: la comunicazione con il fornitore si interrompe prima della ricezione dell’esito. Il sistema lascia la quota nello stato non versato, non registra alcun addebito e invita il Giocatore a verificare prima di ripetere l’operazione (cfr. RNF_A_3).

## RF collegati

### RF_PAG: GESTIONE PAGAMENTI

- **RF_PAG_1 | PagamentoQuota | Alta**: Il sistema deve permettere al Giocatore di poter versare la propria quota di partecipazione entro il termine indicato, una volta raggiunto il numero di partecipanti previsto per la partita.
- **RF_PAG_2 | RicezionePagamentoCampo | Alta**: Il gestore del campo deve ricevere l’importo dovuto per lo slot prenotato, al netto della commissione trattenuta dalla piattaforma.
- **RF_PAG_3 | RimborsoQuote | Alta**: Se la partita viene annullata dall’organizzatore o per mancato versamento di una o più quote entro il termine previsto, il sistema deve rimborsare ai giocatori le quote già versate.
- **RF_PAG_4 | StatoPagamenti | Media**: Il sistema deve permettere al Giocatore di visualizzare il numero di quote ancora da versare per la partita a cui è iscritto.

## Requisiti speciali

- **RNF_A_3 | IntegritaTransazioniPagamento | Alta**: In caso di interruzione della comunicazione con il fornitore di pagamento, il sistema non deve addebitare due volte la stessa quota né registrare come versata una quota il cui esito non è stato confermato
- **RNF_PRE_1 | NotificheStatoPartita | Media**: Il sistema deve recapitare le notifiche di aggiornamento sullo stato della partita entro un massimo di 5 minuti dall’evento scatenante (vincolo di progetto per notifiche non critiche).
- **RNF_PRE_3 | TempestivitàRimborso | Alta**: il rimborso deve essere disposto entro 5 giorni lavorativi dall’annullamento della partita nel 90% dei casi (riferimento: tempi standard di storno/rimborso bancario nell’area SEPA, generalmente entro 3–5 giorni lavorativi).
- **RNF_IN_1 | SicurezzaDatiPagamento | Alta**: Il sistema deve interfacciarsi con un fornitore esterno di servizi di pagamento per l’incasso delle quote e l’accredito al gestore del Campo; i dati delle carte e le coordinate bancarie non devono transitare né essere memorizzati dal sistema, che conserva unicamente l’identificativo dell’account presso il fornitore.
- **RNF_IMP_1 | VincoliTecnologici | Alta**: Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging.

## Tabella degli oggetti

- `Quota` (Entity): Rappresenta quanto dovuto. Contiene i dati relativi alla quota di partecipazione dovuta da un giocatore per una partita, con il relativo stato di versamento. È collegata alla specifica Partecipazione.
- `Transazione` (Entity): Registra un’operazione economica di tipo pagamento, rimborso o accredito (non è obbligatoriamente collegata a una singola Quota). Il pagamento è riferito alla Quota, il rimborso al pagamento originario, l'accredito alla Prenotazione e al Gestore destinatario. Conserva importo, stato, date e riferimento esterno.
- `GestioneTransazioniControl` (Control): Realizza UC_PAG_1 e i requisiti RF_PAG_1, RF_PAG_2, RF_PAG_3: coordina pagamenti, rimborsi e accrediti attraverso GatewayPagamenti. Registra gli esiti, evita duplicazioni, segnala il completamento di tutte le quote, esplicita la gestione delle scadenze e il coordinamento dell'annullamento.
- `GestioneCampiControl` (Control): Realizza la configurazione della struttura introdotta in RF_ACC_1:Coordina configurazione e modifica dei campi, delle tariffe e delle disponibilità, verificando che l’utente sia il gestore autorizzato
- `InterfacciaPagamento` (Boundary): mostra quota e scadenza, raccoglie la conferma per procedere e comunica lo stato dell’operazione e dell’eventuale rimborso
- `GatewayPagamenti` (Boundary): Gestisce lo scambio di richieste ed esiti tra Kickly e il fornitore esterno per pagamenti, rimborsi ed accrediti
- `DashboardGestore` (Boundary): Permette di configurare campi, tariffe e disponibilità e consultare prenotazione e accrediti
