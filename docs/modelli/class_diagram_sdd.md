# Kickly – Class diagram ristrutturato (SDD v1.4, sezione 4.2)

Trascrizione testuale del class diagram ristrutturato dell'SDD
(`docs/fonti/Kickly_SDD_v1.4.pdf`, §4.2). E' la specifica per migration,
entity Dart e repository finche' non c'e' `class.puml` (KCK-201), che dovra'
coincidere con questo file. **Non si aggiungono classi, attributi o tipi:**
se serve qualcosa che qui non c'e', si chiede ai PM.

Il diagramma ha **13 classi**, attributi tutti privati, metodi non indicati.
La molteplicita' scritta accanto a una classe dice quanti oggetti di quella
classe partecipano all'associazione.

## 1. Classi e attributi

| Classe | Attributi |
|---|---|
| Account | ruoloAccount: String, nome: String, cognome: String, email: String, password: String, eta: int, statoAccount: String, statoOnboarding: String, preferenzeNotifiche: String |
| GestoreCampo (estende Account) | idAccountPagamenti: String |
| Giocatore (estende Account) | ruoloPreferitoInCampo: String, piedeDominante: String |
| Notifica | tipo: String, messaggio: String, statoLettura: boolean, timestamp: Date |
| DispositivoRegistrato | identificativo: String, primoAccesso: Date, ultimoAccesso: Date |
| Campo | nome: String, ubicazione: String, tariffaOraria: float, orariDisponibilita: String |
| Lega | nome: String, tipologiaMatch: String, privacy: String, codiceInvito: String, scadenzaCodiceInvito: Date |
| Partita | dataOra: Date, tipologia: String, privacy: String, numPartecipantiRichiesti: int, stato: String, linkCondivisione: String |
| Prenotazione | intervallo: String, statoBlocco: String, scadenzaBlocco: Date, costoConcordato: float, quotaIndividuale: float, commissione: float, nettoGestore: float |
| Partecipazione | rispostaStato: String, dataRisposta: Date, golPartita: int, assistPartita: int |
| VotazioneMVP | statoVotazione: String, scadenza: Date, preferenzeVotanteVotato: Map<Giocatore, Giocatore>, vincitore: Giocatore [0..1] |
| Transazione | tipo: String, importo: float, stato: String, dataEsito: Date, riferimentoEsterno: String |
| Quota | importo: float, statoVersamento: String, termineVersamento: Date |

## 2. Associazioni

I nomi di ruolo delle associazioni che nel diagramma non hanno nome sono presi
dal glossario del RAD (§1.4) e dalla tabella degli oggetti (§3.4.4.1).

| # | Associazione | Nome di ruolo (dal RAD) |
|---|---|---|
| 1 | Account 1 — 0..* Notifica | notifiche dell'account |
| 2 | Account 1 — 0..* DispositivoRegistrato | dispositivi dell'account |
| 3 | GestoreCampo 1 — 0..* Campo | campi del gestore |
| 4 | Campo 1 — 0..* Prenotazione | prenotazioni del campo |
| 5 | Prenotazione 0..1 — 1 Partita | prenotazione dello slot della partita |
| 6 | Prenotazione 0..1 — 0..* Transazione | accrediti della prenotazione |
| 7 | GestoreCampo 0..1 — 0..* Transazione | accrediti al gestore |
| 8 | Lega 0..* — 0..* Giocatore | **membri** della lega |
| 9 | Lega 0..* — 1..* Giocatore | **amministratori** della lega (almeno uno: chi la crea) |
| 10 | Lega 0..1 — 0..* Partita | partite della lega (partita pubblica = senza lega) |
| 11 | Giocatore 1 — 0..* Partita | **organizzatore** della partita |
| 12 | Giocatore 1 — 0..* Partecipazione | partecipazioni del giocatore |
| 13 | Partita 1 — 0..* Partecipazione | partecipanti della partita |
| 14 | Partita 1 — 0..1 VotazioneMVP | votazione della partita |
| 15 | Partecipazione 1 — 0..1 Quota | quota del partecipante |
| 16 | Quota 0..1 — 0..* Transazione | pagamenti e rimborsi della quota |
| 17 | Transazione 0..1 — 0..1 Transazione | **transazioneOriginaria**: il rimborso si riferisce al pagamento originario |

Generalizzazioni: GestoreCampo e Giocatore estendono Account.

## 3. Mappatura sul database e sul codice (decisione dei PM)

Regola generale: nomi e tipi come nel diagramma. Le sole scelte sotto servono
a realizzare il diagramma su Supabase senza aggiungere elementi al modello.

1. **Attributi di stato e di tipo restano String** (stato, statoVersamento,
   statoBlocco, rispostaStato, statoVotazione, statoAccount, tipo, privacy,
   tipologia...). Nel database i valori ammessi si controllano con un vincolo
   CHECK; in Dart con costanti. Niente tipi enum nuovi. I valori si prendono dal
   RAD: per `Partita.stato` quelli dello statechart (es. Aperta, Completa,
   Conclusa, Annullata).
2. **`Account.password`** e' realizzata da Supabase Auth (`auth.users`, con
   hash): non e' una colonna delle tabelle pubbliche e l'entity Dart non la
   serializza. Il valore passa solo dalla GUI al Control di registrazione/login.
3. **Associazioni molti-a-molti 8 e 9**: due tabelle di collegamento,
   `membro_lega` e `amministratore_lega`. Chi crea la lega e' inserito in
   entrambe (molteplicita' 1..*).
4. **`Prenotazione.intervallo`** resta String con un formato unico di slot
   (es. `2026-11-20T18:00/2026-11-20T19:00`) ricavato da
   `Campo.orariDisponibilita`. Le sovrapposizioni si evitano con un vincolo
   UNIQUE su (campo, intervallo) per le prenotazioni con `statoBlocco` attivo,
   insieme a `scadenzaBlocco` per liberare gli slot non confermati.
5. **`Campo.orariDisponibilita`** e' una colonna di Campo, non una tabella.
6. **`VotazioneMVP.preferenzeVotanteVotato`** (mappa votante -> votato) e' una
   tabella (votazione, votante, votato) con UNIQUE (votazione, votante);
   `vincitore` e' una chiave esterna facoltativa verso Giocatore.
7. **Idempotenza dei pagamenti**: `Transazione.riferimentoEsterno` (id
   dell'evento del fornitore) e' UNIQUE. Nessuna colonna in piu'.
8. **Chiavi esterne dalle molteplicita'**: lato "1" = NOT NULL, lato "0..1" =
   facoltativa. Quindi `prenotazione.partita` NOT NULL e UNIQUE,
   `partita.organizzatore` NOT NULL, `partita.lega` facoltativa,
   `quota.partecipazione` NOT NULL e UNIQUE, `votazione_mvp.partita` NOT NULL e
   UNIQUE, `partecipazione` UNIQUE (giocatore, partita).
9. id e chiavi esterne sono attributi tecnici di mappatura, non del modello. Nel codice si chiamano `id` (chiave della classe) e `<entity>Id` (chiavi esterne), e corrispondono alle colonne `id` e `<entity>_id` del database (es. `accountId` ↔ `account_id`). Le sottoclassi di Account ereditano `id`; nel database la loro chiave è `account_id`.
