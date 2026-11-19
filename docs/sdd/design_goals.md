# Design Goals, Trade-off e Mapping Hardware/Software

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | KCK-260 |
| **Versione** | 0.2 |
| **Data** | 19/11/2026 |
| **Autori** | Gabriele Karol Vicinanza |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 19/11/2026 | 0.2 | Riallineamento fedele a Kickly_SDD_v1.0.pdf, sezioni 1.2 e 1.3 | Gabriele Karol Vicinanza |
| 19/11/2026 | 0.1 | Prima stesura | Gabriele Karol Vicinanza |

## Indice

1. [Design Goals](#12-design-goals)
2. [Trade-off](#13-trade-off)
3. [Decomposizione in sottosistemi](#32-decomposizione-in-sottosistemi)
4. [Mapping Hardware/Software](#33-mapping-hardwaresoftware)

## 1.2 Design Goals

| Rank | ID Design Goal | Nome | Descrizione | Categoria | RNF di Origine |
|---|---|---|---|---|---|
| 1 | DG_9 | Sicurezza dei dati di pagamento | Il sistema deve delegare al fornitore esterno di pagamento (Stripe Connect) il 100% delle operazioni di incasso delle quote, rimborso e accredito al Gestore del Campo, in modo che nessun dato di carta o coordinata bancaria transiti nell’applicazione né venga memorizzato nei suoi archivi: dei dati di pagamento il sistema conserva unicamente l’identificativo dell’account presso il fornitore, con 0 campi contenenti numero di carta, CVV o IBAN nello schema della base di dati e 0 endpoint applicativi abilitati a riceverli. | Dependability | RNF_IN_1 |
| 2 | DG_10 | Robustezza transazionale | A fronte di interruzioni della comunicazione con il fornitore di pagamento, il sistema non deve addebitare due volte la stessa quota (anche in caso di nuovo tentativo del Giocatore) né registrare come versata una quota il cui esito non è stato confermato: ogni richiesta di pagamento è identificata da un riferimento idempotente, la Quota passa allo stato "Versata" solo alla ricezione dell'esito positivo e le operazioni rimaste in sospeso vengono riconciliate | Dependability | RNF_A_3 |
| 3 | DG_5 | Affidabilità | Il sistema deve elaborare le richieste concorrenti di conferma o ritiro presenza (RSVP) garantendo un tasso di successo e disponibilità del 99,9% ("three nines"), mantenendo un tasso di overbooking dello 0% assoluto sull'aggiornamento del contatore. | Dependability | RNF_A_2 |
| 4 | DG_11 | Conformità GDPR | Il sistema deve supportare la cancellazione irreversibile dei dati personali: a seguito della richiesta di eliminazione dell’account, deve cancellare in modo definitivo tutti i dati personali dell’utente dai propri archivi entro 30 giorni dalla richiesta, conservando unicamente i dati che è tenuto a mantenere per obblighi di legge (le transazioni di pagamento), che vengono dissociati dall’identità dell’utente. | Dependability | RNF_L_1 |
| 5 | DG_2 | Affidabilità | Il sistema deve aggiornare le statistiche della Player Card (gol, assist, presenze, MVP) entro 1 minuto dalla chiusura di ciascun incontro, senza perdite in caso di riavvio o malfunzionamento e in modo coerente con lo storico degli incontri. | Dependability | RNF_A_1 |
| 6 | DG_1 | Usabilità | Il sistema deve permettere a un nuovo utente di completare registrazione, scelta del ruolo e configurazione della Player Card senza assistenza esterna in meno di 3 minuti. | End User | RNF_U_1 |
| 7 | DG_3 | Usabilità | L’interfaccia utente deve permettere a un Giocatore autenticato di unirsi a una lega, privata o pubblica, inserendo il codice d’invito o accedendo tramite link di condivisione, con un massimo di 3 interazioni (tap/click) e senza richiedere di reinserire dati già forniti. | End User | RNF_U_2 |
| 8 | DG_7 | Prestazioni | Il sistema deve elaborare la registrazione del voto MVP entro un tempo massimo di 10 secondi, in modo da non bloccare l’interfaccia. | Performance | RNF_PRE_2 |
| 9 | DG_8 | Implementazione | Il sistema deve essere realizzato con un’unica base di codice Flutter, distribuibile senza modifiche sia su Android sia su iOS, appoggiandosi a Supabase per la persistenza dei dati e l’autenticazione e a Firebase Cloud Messaging per le notifiche push. L’accesso a questi servizi deve essere confinato al Data Layer, con 0 riferimenti diretti agli SDK di Supabase e FCM nel Presentation Layer e nel Domain Layer, in modo che la sostituzione di un servizio esterno richieda modifiche ai soli repository. | Maintenance | RNF_IMP_1 |
| 10 | DG_12 | Autoconsistenza del pacchetto | Il pacchetto di installazione distribuito deve contenere il 100% delle dipendenze e librerie client, garantendo il primo avvio dell'applicazione con 0 download di software aggiuntivi richiesti all'utente. | End User | RNF_P_1 |
| 11 | DG_6 | Prestazioni | Il sistema deve elaborare e recapitare le notifiche relative agli aggiornamenti di stato della partita ai dispositivi dei giocatori iscritti entro un tempo limite tassativo di 5 minuti (300 secondi) dall'evento scatenante. | Performance | RNF_PRE_1 |
| 12 | DG_4 | Estensibilità | L’architettura software deve impiegare pattern di progettazione disaccoppiati per consentire l’aggiunta di nuove tipologie di lega o di nuovi canali di condivisione degli inviti, senza modificare la logica di gestione dei membri. | Maintenance | RNF_S_1 |

## 1.3 Trade-off

| Trade-off | Descrizione |
|---|---|
| Affidabilità delle adesioni e sicurezza dei pagamenti (DG_5, DG_9) Vs Implementazione (DG_8) | Per garantire lo 0% di overbooking sul contatore RSVP (DG_5, Rank 3) e mantenere la chiave segreta del fornitore di pagamento solo lato server (DG_9, Rank 1), la logica critica del contatore RSVP e dei pagamenti viene eseguita nelle Edge Functions di Supabase e non nello strato Data dell’applicazione. La sostituzione di Supabase richiederebbe quindi la riscrittura di tali funzioni, oltre alla modifica dei repository (DG_8, Rank 9). Si sacrifica parte della sostituibilità dei servizi esterni a favore della correttezza e della sicurezza. della protezione del dato. |
| Conformità GDPR (DG_11) Vs Affidabilità (DG_2) | Per ottemperare agli obblighi di legge garantendo la cancellazione irreversibile e definitiva dei dati personali entro 30 giorni (DG_11, Rank 4), le identità vengono rimosse e dissociate dalle partite concluse. Questo comporta un sacrificio nella conservazione assoluta e coerente delle statistiche storiche e delle Player Card per le partite passate (DG_2, Rank 5), privilegiando la tutela legale. |

## 3.2 Decomposizione in sottosistemi

Basandosi sulle caratteristiche del sistema e sui requisiti individuati nel RAD, sono stati individuati i seguenti sottosistemi, che corrispondono alle sei aree di sistema del RAD più la Persistenza:

- **Gestione Utenza:** si occupa di gestire registrazione, autenticazione e recupero della password, la scelta definitiva del ruolo (Giocatore o Gestore del Campo) in onboarding e la configurazione della Player Card.
- **Gestione Leghe e Inviti:** si occupa della creazione e modifica delle leghe (pubbliche o private), della generazione dei codici e dei link di invito, dell’adesione e della gestione di membri e amministratori, e della dashboard della lega.
- **Gestione Partite e RSVP:** si occupa del ciclo di vita della partita, della verifica e del blocco dello slot del campo, della conferma o del ritiro della presenza (RSVP) con aggiornamento dei posti disponibili, e dell’annullamento.
- **Gestione Voto MVP e Notifiche:** si occupa del voto MVP a fine partita, dell’aggiornamento di statistiche e classifica, e dell’invio e della consultazione delle notifiche con le relative preferenze.
- **Gestione Strutture e Pagamenti:** si occupa della configurazione di campi, tariffe e disponibilità da parte del Gestore del Campo, e dell’incasso delle quote, dell’accredito al Gestore e dei rimborsi tramite il fornitore esterno di pagamento. Riunisce l’area dei pagamenti del RAD con la configurazione della struttura sportiva.
- **Gestione Rete Sociale e Sicurezza:** si occupa della condivisione delle partite pubbliche tramite link univoco, della rilevazione degli accessi da nuovi dispositivi con email di allerta, e della cancellazione dell’account (GDPR).
- **Persistenza:** si occupa dell’accesso ai dati su PostgreSQL/Supabase tramite il pattern Repository, facendo da tramite tra i sottosistemi e la base di dati.

## 3.3 Mapping Hardware/Software

Kickly si presenta come un’applicazione mobile realizzata con un’unica base di codice Flutter e distribuita sia su dispositivi Android sia su dispositivi iOS. L’applicazione viene installata sullo smartphone del Giocatore o del Gestore del Campo e contiene al suo interno tutte le dipendenze necessarie al primo avvio. Il dispositivo client ospita l’interfaccia, la logica applicativa e l’accesso ai dati, mentre il token di sessione è conservato nel Secure Storage del sistema operativo. Il sistema risiede quindi su due nodi: lo smartphone dell’utente e il cloud di Supabase.

Per i dati persistenti e per la logica critica il sistema si appoggia a Supabase, utilizzata come Backend as a Service, che comprende:

- un database relazionale **PostgreSQL** protetto da policy di Row Level Security (RLS);
- il servizio di **autenticazione**;
- un **API Gateway** che espone i dati come API REST;
- il servizio **Realtime** per gli aggiornamenti in tempo reale;
- le **Edge Functions**, che eseguono le operazioni che non possono essere affidate al client (contatore RSVP, pagamenti, cancellazione dell’account, invio di notifiche ed email).

Si è scelto un servizio gestito al posto di un server proprio per non dover mantenere l’infrastruttura. La chiave segreta di Stripe resta solo lato server.

Il sistema si appoggia inoltre a tre servizi esterni:

- **Stripe Connect** per incassi, accrediti e rimborsi, in modo che nessun dato di carta transiti nell’applicazione;
- **Firebase Cloud Messaging** per le notifiche push;
- un **servizio email** per il recupero della password e l’allerta sugli accessi.

La comunicazione tra client e server avviene tramite HTTPS (REST/JSON) e WSS per gli aggiornamenti in tempo reale; anche i collegamenti verso i servizi esterni sono cifrati (HTTPS e, per le email inviate da Supabase Auth, SMTP su TLS).
