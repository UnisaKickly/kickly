# Category partition - UC_MVP_1 Assegnazione voto MVP della partita e UC_SS_1 Condivisione partita

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/UC_MVP_1_VotoMVP.md`, `docs/rad/uc/UC_SS_1_CondivisionePartita.md` |
| **Requisiti** | RF_POS_1, RF_POS_2, RF_NOT_1, RF_NOT_2, RF_SS_1, RF_SS_2, RNF_L_1; SDD v1.4 DG4 (conformita' GDPR) |
| **Metodo testato** | Una funzione per sezione (vedi §1): `VotoMVPControl`, `ClassificaControl`, `NotificaControl`, `PreferenzeNotificheControl`, `GestioneCondivisioneControl`, `SicurezzaAccessiControl`, `CancellazioneAccountControl` (tabella degli oggetti del RAD). Il RAD non definisce le firme: i metodi si propongono nel piano dei ticket che implementano i Control |
| **Autori** | Antonio Tolino |
| **Revisori** | Mario Celzo, Renato Mancino |

Metodo: category partition (Ostrand e Balcer, 1988). Il sistema e' diviso in
funzioni testabili in modo indipendente; per ogni funzione si individuano
parametri e condizioni dell'ambiente, le loro categorie e le scelte (valori
normali, limite, speciali e di errore), poi i vincoli tra le scelte. Un test
frame e' una combinazione valida con **una scelta per ogni categoria della
stessa funzione**: le categorie di funzioni diverse non si combinano. Una scelta
`[error]` o `[single]` produce un solo frame e non si combina con le altre.

Fonti degli esiti attesi: i casi d'uso UC_MVP_1 e UC_SS_1, RAD v2.9 §3.2
(RF_POS_1, RF_POS_2, RF_NOT_1, RF_NOT_2, RF_SS_1, RF_SS_2) e §3.3 (RNF_L_1), la
tabella degli oggetti (§3.4.4.1.4 e §3.4.4.1.6), SDD v1.4 DG4 e
`docs/modelli/DECISIONI_RAD.md` (D1, D2, D9, D10, D12, D13, D14, D15). Dove il RAD
non dice l'esito, l'esito viene dalle decisioni dei PM (risposte alle domande
della sezione 4): nessun esito e' stato ipotizzato. Resta da completare solo
TF_SS_11, che D12 affida al piano di KCK-204 / KCK-212.

Fuori dai frame: RNF_PRE_2 (DG8, voto registrato entro 10 secondi), RNF_A_1
(DG5, statistiche aggiornate entro 1 minuto e senza perdite) e RNF_PRE_1 (DG11,
notifiche entro 5 minuti) sono soglie di prestazione e affidabilita': non sono
scelte di un parametro o dell'ambiente ma proprieta' da misurare a parte, come
RNF_PRE_3 in `cp_UC_PAR_1_UC_PAG_1.md`.

## 1. Funzioni, parametri e condizioni dell'ambiente

| Funzione | Control | Requisiti | Parametri | Condizioni dell'ambiente |
|---|---|---|---|---|
| F1 Voto MVP | `VotoMVPControl` | UC_MVP_1, RF_POS_1 | giocatore votato | stato della partita; partecipazione del votante; voto gia' espresso nella stessa `VotazioneMVP`; connessione all'accesso alla sezione e alla conferma |
| F2 Classifica | `ClassificaControl` | RF_POS_2 | nessuno (consultazione) | titoli MVP assegnati; gol e assist inseriti (D2); parita' di titoli |
| F3 Invio notifica | `NotificaControl` | RF_NOT_1, RF_NOT_2 | evento rilevante | preferenza del destinatario per quella tipologia |
| F4 Consultazione notifica | `NotificaControl` | RF_NOT_1, tabella degli oggetti | notifica aperta | stato di lettura |
| F5 Preferenze notifiche | `PreferenzeNotificheControl` | RF_NOT_2 | operazione sulla tipologia | nessuna |
| F6 Condivisione partita | `GestioneCondivisioneControl` | UC_SS_1, RF_SS_1 | opzione scelta nel menu di condivisione | privacy della partita; iscrizione del Giocatore; connessione alla generazione del link |
| F7 Accesso da dispositivo | `SicurezzaAccessiControl` | RF_SS_2 | dispositivo di accesso | dispositivi gia' registrati per l'Account |
| F8 Cancellazione account | `CancellazioneAccountControl` | RNF_L_1, DG4 | nessuno (richiesta di eliminazione) | transazioni da conservare; Account unico amministratore di una lega (D12) |

## 2. Categorie e scelte

Vincoli: `[error]` scelta che porta a un errore o a un'operazione rifiutata (un
solo frame); `[single]` caso speciale o limite da provare una sola volta;
`[property X]` / `[if X]` solo dove servono a escludere combinazioni
contraddittorie.

### F1 Voto MVP

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato della partita | Conclusa | |
| Stato della partita | non Conclusa | `[error]` |
| Partecipazione del votante | ha partecipato alla partita | |
| Partecipazione del votante | non ha partecipato | `[error]` |
| Voto gia' espresso | no | |
| Voto gia' espresso | si', nella stessa votazione | `[error]` (flusso alternativo 3.1: operazione bloccata) |
| Giocatore votato | un altro partecipante | |
| Giocatore votato | se stesso (valore limite) | `[single]` |
| Connessione all'accesso alla sezione | raggiungibile | |
| Connessione all'accesso alla sezione | non raggiungibile | `[error]` |
| Connessione alla conferma | raggiungibile | |
| Connessione alla conferma | non raggiungibile | `[error]` |

### F2 Classifica

| Categoria | Scelta | Vincolo |
|---|---|---|
| Titoli MVP assegnati | almeno un giocatore con titoli | |
| Titoli MVP assegnati | nessuno (classifica vuota, valore limite) | `[single]` |
| Gol e assist | inseriti dall'Organizzatore | |
| Gol e assist | non inseriti (D2) | `[single]` |
| Parita' | titoli MVP diversi | |
| Parita' | due giocatori a pari merito | `[single]` |

### F3 Invio notifica

| Categoria | Scelta | Vincolo |
|---|---|---|
| Evento rilevante | apertura del sondaggio MVP (D1) | |
| Evento rilevante | apertura delle convocazioni per una partita | `[single]` |
| Preferenza del destinatario | tipologia attiva | |
| Preferenza del destinatario | tipologia disattivata | |

### F4 Consultazione notifica

| Categoria | Scelta | Vincolo |
|---|---|---|
| Stato di lettura | non letta | |

Una sola scelta per la categoria: il metodo lo ammette (slide "Scelte").

### F5 Preferenze notifiche

| Categoria | Scelta | Vincolo |
|---|---|---|
| Operazione | attivare una tipologia | |
| Operazione | disattivare una tipologia | |
| Operazione | personalizzare una tipologia | |

### F6 Condivisione partita

| Categoria | Scelta | Vincolo |
|---|---|---|
| Privacy della partita | pubblica (non appartiene ad alcuna lega, RF_SS_1) | |
| Privacy della partita | non pubblica | `[error]` |
| Iscrizione del Giocatore | iscritto | |
| Iscrizione del Giocatore | non iscritto | `[error]` |
| Connessione alla generazione del link | raggiungibile | |
| Connessione alla generazione del link | non raggiungibile | `[error]` |
| Opzione nel menu | Copia link | |
| Opzione nel menu | app di terze parti (es. WhatsApp) | |
| Opzione nel menu | chiude il menu senza scegliere | `[single]` |

### F7 Accesso da dispositivo

| Categoria | Scelta | Vincolo |
|---|---|---|
| Dispositivo di accesso | gia' registrato per l'Account | |
| Dispositivo di accesso | mai registrato | |

### F8 Cancellazione account

| Categoria | Scelta | Vincolo |
|---|---|---|
| Transazioni da conservare | nessuna | |
| Transazioni da conservare | una o piu' transazioni di pagamento (obblighi di legge) | |
| Amministrazione di leghe | non e' l'unico amministratore di una lega | |
| Amministrazione di leghe | e' l'unico amministratore di una lega (D12) | `[single]` |

## 3. Test frame

L'esito atteso si prende dal caso d'uso, dagli RF/RNF, dalla tabella degli
oggetti, dai DG e dalle decisioni dei PM, mai dal comportamento del codice. Ogni
frame avra' un test con l'id in minuscolo nel nome (es. `tf_mvp_01_...`) nel
ticket che implementa il Control corrispondente.

### 3.1 F1 Voto MVP (UC_MVP_1, RF_POS_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_MVP_01 | Conclusa, ha partecipato, nessun voto, un altro partecipante, accesso e conferma raggiungibili | Partita "Conclusa" con `VotazioneMVP` aperta (D1); Giocatore autenticato tra i partecipanti | Il sistema mostra l'elenco dei partecipanti; dopo la conferma salva la preferenza nella `VotazioneMVP`, aggiorna i dati statistici del giocatore votato e mostra un messaggio di successo | UC_MVP_1 passi 1-6, RF_POS_1 |
| TF_MVP_02 | voto gia' espresso | Il Giocatore ha gia' votato nella stessa votazione | Il sistema blocca l'operazione e mostra un messaggio di avviso; il voto precedente resta invariato (un solo voto per giocatore nella stessa votazione) | UC_MVP_1 flusso alternativo 3.1, tabella degli oggetti (`VotazioneMVP`) |
| TF_MVP_03 | non ha partecipato | Giocatore autenticato che non ha partecipato alla partita "Conclusa" | Il comando di voto non e' visibile; una richiesta diretta viene rifiutata con "Solo i partecipanti possono votare" e nessun voto e' registrato | UC_MVP_1 passo 2 (elenco dei partecipanti), D13 |
| TF_MVP_04 | partita non Conclusa | Partita in stato diverso da "Conclusa" | Il comando "Vota MVP" non e' disponibile (la votazione si apre solo alla conclusione); una richiesta diretta viene rifiutata con un messaggio di errore e nessun voto e' registrato | Entry condition UC_MVP_1, D1, D13 |
| TF_MVP_05 | connessione non raggiungibile all'accesso alla sezione | Connessione assente quando il Giocatore apre il dettaglio della partita | Il sistema notifica l'errore invitando a riprovare piu' tardi; nessun voto registrato | UC_MVP_1 flusso di errore 1.1 |
| TF_MVP_06 | connessione non raggiungibile alla conferma | Connessione assente al momento della conferma del voto | Il sistema notifica l'errore invitando a riprovare piu' tardi; il voto non e' registrato e il Giocatore e' avvisato | UC_MVP_1 flusso di errore 4.1, exit condition on failure |
| TF_MVP_07 | il Giocatore vota se stesso | Il Giocatore prova a votare se stesso | L'autovoto non e' ammesso: il votante non compare nell'elenco dei giocatori votabili; una richiesta di voto per se stesso viene rifiutata con un messaggio di errore e il voto non e' registrato | UC_MVP_1 passo 2, D14 |

### 3.2 F2 Classifica (RF_POS_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_MVP_08 | almeno un giocatore con titoli, gol e assist inseriti, titoli diversi | Piu' partite concluse con vincitori MVP diversi e gol/assist inseriti | La classifica mostra i giocatori ordinati per titoli MVP vinti, distinguendo i voti ricevuti dai titoli, con gol e assist | RF_POS_2, tabella degli oggetti (`ClassificaControl`) |
| TF_MVP_09 | classifica vuota | Nessuna votazione conclusa: nessun giocatore ha titoli MVP | La classifica mostra il messaggio "Nessuna classifica disponibile" | RF_POS_2, D15 |
| TF_MVP_10 | gol e assist non inseriti | Partite concluse con vincitori MVP ma senza gol e assist inseriti dall'Organizzatore | La classifica mostra i titoli MVP; gol e assist compaiono a 0 | RF_POS_2, D2 |
| TF_MVP_11 | due giocatori a pari merito | Due giocatori con lo stesso numero di titoli MVP | A parita' di titoli MVP l'ordine e' dato dai voti ricevuti, poi dai gol, poi dagli assist, poi dall'ordine alfabetico del nome | RF_POS_2, D15 |

### 3.3 F3 Invio notifica (RF_NOT_1, RF_NOT_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_NOT_01 | apertura sondaggio MVP, tipologia attiva | Partita appena passata a "Conclusa" (D1); destinatario con la tipologia attiva | Viene creata una `Notifica` in-app per il destinatario, con tipo, messaggio, data e stato "non letta" | RF_NOT_1, D1, tabella degli oggetti (`Notifica`) |
| TF_NOT_02 | apertura sondaggio MVP, tipologia disattivata | Come TF_NOT_01, ma il destinatario ha disattivato quella tipologia | Nessuna `Notifica` di quella tipologia viene creata per il destinatario | RF_NOT_2 |
| TF_NOT_03 | apertura delle convocazioni | Convocazioni aperte per una partita; destinatario con la tipologia attiva | Viene creata una `Notifica` in-app per il destinatario, con tipo, messaggio, data e stato "non letta" | RF_NOT_1 |

### 3.4 F4 Consultazione notifica (RF_NOT_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_NOT_04 | notifica non letta | Account con una `Notifica` non letta nel `PannelloNotifiche` | Aprendo la notifica lo stato di lettura diventa "letta" e la notifica resta consultabile | Tabella degli oggetti (`NotificaControl`, `PannelloNotifiche`) |

### 3.5 F5 Preferenze notifiche (RF_NOT_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_NOT_05 | attivare una tipologia | Tipologia disattivata nelle preferenze dell'Account | La tipologia risulta attiva nelle preferenze salvate nell'Account | RF_NOT_2, tabella degli oggetti (`PreferenzeNotificheControl`), D10 |
| TF_NOT_06 | disattivare una tipologia | Tipologia attiva nelle preferenze dell'Account | La tipologia risulta disattivata nelle preferenze salvate nell'Account | RF_NOT_2, D10 |
| TF_NOT_07 | personalizzare una tipologia | Tipologia attiva; l'utente ne modifica la personalizzazione | La personalizzazione e' salvata nelle preferenze dell'Account | RF_NOT_2, D10 |

### 3.6 F6 Condivisione partita (UC_SS_1, RF_SS_1)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_SS_01 | pubblica, iscritto, connessione raggiungibile, Copia link | Giocatore autenticato nel dettaglio di una partita pubblica a cui e' iscritto | Il sistema genera un link univoco della partita e apre il menu di condivisione nativo; scelto "Copia link", chiude il menu e mostra "Link copiato!" | UC_SS_1 passi 1-5, RF_SS_1 |
| TF_SS_02 | pubblica, iscritto, connessione raggiungibile, app di terze parti | Come TF_SS_01 | Il sistema genera il link univoco e apre il menu nativo; scelta un'app di terze parti, chiude il menu e apre l'applicazione corrispondente | UC_SS_1 passi 1-5, RF_SS_1 |
| TF_SS_03 | chiude il menu senza scegliere | Link generato e menu nativo aperto | Il sistema annulla l'operazione e il Giocatore resta sulla schermata di dettaglio della partita | UC_SS_1 flusso alternativo A1, exit condition on failure |
| TF_SS_04 | connessione non raggiungibile | Connessione assente quando il sistema deve generare il link | Il link non viene generato; il sistema notifica l'errore invitando a riprovare e si riprende dal passo 1 | UC_SS_1 flusso di errore E1 |
| TF_SS_05 | partita non pubblica | Partita privata o appartenente a una lega | Il comando "Condividi" non e' disponibile; una richiesta diretta viene rifiutata con un messaggio di errore e nessun link e' generato | Entry condition UC_SS_1, RF_SS_1, D13 |
| TF_SS_06 | Giocatore non iscritto | Partita pubblica a cui il Giocatore non e' iscritto | Il comando "Condividi" non e' disponibile; una richiesta diretta viene rifiutata con un messaggio di errore e nessun link e' generato | Entry condition UC_SS_1, D13 |

### 3.7 F7 Accesso da dispositivo (RF_SS_2)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_SS_07 | dispositivo gia' registrato | Login da un dispositivo presente tra i `DispositivoRegistrato` dell'Account | Nessuna email di allerta e nessun nuovo `DispositivoRegistrato` | RF_SS_2 |
| TF_SS_08 | dispositivo mai registrato | Login da un dispositivo mai usato con quell'Account | Il nuovo dispositivo viene registrato (`DispositivoRegistrato` con primo e ultimo accesso) e il sistema richiede l'invio dell'email di allerta tramite `ServizioEmail` | RF_SS_2, scenario SC_SS_2, tabella degli oggetti (`SicurezzaAccessiControl`) |

### 3.8 F8 Cancellazione account (RNF_L_1, DG4)

| Id | Scelte combinate | Preparazione | Esito atteso | Fonte |
|---|---|---|---|---|
| TF_SS_09 | nessuna transazione, non unico amministratore | L'utente richiede l'eliminazione dell'account | L'Account passa a `in_cancellazione`; entro 30 giorni dalla richiesta tutti i dati personali sono cancellati in modo definitivo dagli archivi | RNF_L_1, DG4, D9 |
| TF_SS_10 | transazioni di pagamento da conservare, non unico amministratore | L'utente con transazioni di pagamento registrate richiede l'eliminazione | Entro 30 giorni i dati personali sono cancellati; le transazioni di pagamento restano conservate ma dissociate dall'identita' dell'utente | RNF_L_1, DG4 |
| TF_SS_11 | unico amministratore di una lega | L'utente e' l'unico amministratore di una lega e richiede l'eliminazione | La cancellazione dei dati personali procede comunque (D12). Come viene risolta la lega: **DA CONFERMARE** nel piano approvato di KCK-204 / KCK-212 (domanda 8) | RNF_L_1, D12 |

Totale frame: 29 (TF_MVP_01..11, TF_NOT_01..07, TF_SS_01..11)

Copertura: UC_MVP_1 3.1 -> TF_MVP_02, 1.1 -> TF_MVP_05, 4.1 -> TF_MVP_06;
UC_SS_1 A1 -> TF_SS_03, E1 -> TF_SS_04. Casi richiesti dal ticket: voto
duplicato (TF_MVP_02), votante non partecipante (TF_MVP_03), partita non
conclusa (TF_MVP_04), preferenza disattivata (TF_NOT_02), nuovo dispositivo
(TF_SS_08), cancellazione con transazioni da dissociare (TF_SS_10).

## 4. Domande per i PM e risposte

Risposte dei PM (Renato Mancino, 19/11/2026), registrate in
`docs/modelli/DECISIONI_RAD.md`.

1. TF_MVP_04, partita non "Conclusa". **Risposta:** comando "Vota MVP" non disponibile; richiesta diretta rifiutata (D1, D13).
2. TF_MVP_03, votante non partecipante. **Risposta:** comando non visibile; richiesta diretta rifiutata con "Solo i partecipanti possono votare" (D13).
3. TF_MVP_07, autovoto. **Risposta:** non ammesso, il votante non e' tra i votabili (D14).
4. TF_MVP_09, classifica vuota. **Risposta:** "Nessuna classifica disponibile" (D15).
5. TF_MVP_11, pari merito. **Risposta:** titoli MVP, poi voti ricevuti, gol, assist, ordine alfabetico (D15).
6. TF_SS_05, partita non pubblica. **Risposta:** comando "Condividi" non disponibile; richiesta diretta rifiutata (D13).
7. TF_SS_06, Giocatore non iscritto. **Risposta:** come la 6 (D13).
8. TF_SS_11, lega dell'unico amministratore cancellato. **Risposta:** resta come da D12: lo decide il piano approvato di `CancellazioneAccountControl` (KCK-204 / KCK-212), dove il frame va completato. Il test di TF_SS_11 si scrive in quel ticket.
