# Registrazione e Onboarding

| | |
|---|---|
| **Progetto** | Kickly |
| **Riferimento** | UC_ACC_1 |
| **Versione** | 1.0.0 |
| **Data** | 01/11/2026 |
| **Autori** | Simona Sceral |
| **Revisori** | Mario Celzo, Renato Mancino |
| **Stato** | Bozza |

## Revision History

| Data | Versione | Descrizione | Autori |
|---|---|---|---|
| 01/11/2026 | 1.0.0 | Stesura del caso d'uso nel RAD v2.9 (sezione 3.4.2.1) | Simona Sceral |
| 19/11/2026 | 1.0.0 | Trascrizione fedele in Markdown dal RAD v2.9 (KCK-193) | Gabriele Karol Vicinanza |

## Identificativo

UC_ACC_1

## Titolo

Registrazione e Onboarding

## Descrizione

Un nuovo utente crea un account su Kickly e completa l’onboarding, scegliendo in modo definitivo il proprio ruolo (Giocatore o Gestore del Campo) e, se Giocatore, configurando la propria Player Card.

## Attori

- **Attore Principale**: Utente non registrato (diventerà Giocatore o Gestore del Campo)
- **Attori secondari**: N/A

## Entry Condition

L’utente ha avviato l’app Kickly e non possiede un account registrato con lo stesso indirizzo email.

## Exit condition On success

L’account è stato creato, il ruolo è stato scelto in modo definitivo e l’utente è stato indirizzato alla configurazione specifica del proprio ruolo (Player Card per il giocatore, configurazione struttura per il Gestore); se Giocatore, la Player Card risulta salvata.

## Exit condition On failure

L’account non viene creato (email già registrata o dati non validi) e l’utente resta sulla schermata di registrazione; oppure l’account viene creato ma l’onboarding resta incompleto (ruolo non scelto o Player Card non configurata) se l’utente abbandona il processo.

## Rilevanza/User Priority

Alta

## Frequenza stimata

20/giorno

## Extension point

NA

## Generalization of

NA

## FLUSSO DI EVENTI PRINCIPALE/MAIN SCENARIO

1. Utente non registrato: L’utente seleziona “Registrati” dalla schermata iniziale.
2. Sistema: Il sistema mostra il modulo di registrazione (nome, cognome, email, password, età).
3. Utente non registrato: L’utente inserisce i dati richiesti e conferma.
4. Sistema: Il sistema valida i dati e crea l’account.
5. Sistema: Il sistema avvia l’onboarding, chiedendo all’utente di scegliere il proprio ruolo.
6. Utente registrato: L’utente seleziona il ruolo “Giocatore”.
7. Sistema: Il sistema registra la scelta come definitiva e reindirizza l’utente alla configurazione della Player Card.
8. Utente registrato: L’utente inserisce il ruolo preferito in campo e il piede dominante, poi conferma.
9. Sistema: Il sistema salva la Player Card e mostra la dashboard, con le statistiche iniziali azzerate.

## Flusso di eventi di errore

- **E1 (Al passo 4)**: Email già registrata, il sistema mostra un errore e propone login o email diversa; si riprende dal passo 3.
- **E2 (Al passo 4)**: Dati non validi (campi mancanti o password debole), il sistema mostra l’errore specifico; si riprende al passo 3.
- **E3 (Dopo il passo 4, prima di 7 o 9)**: Onboarding interrotto, l’account resta incompleto; al successivo accesso il sistema ripropone il passo interrotto.

## I Scenario/Flusso di eventi Alternativo

- **A1 (Al passo 6)**: L’utente seleziona “Gestore del Campo” invece di “Giocatore”. Il sistema registra la scelta e reindirizza l’utente alla configurazione della propria struttura sportiva, al posto dei passi 7-9.

## RF collegati

- **RF_ACC_1 | RegistrazioneGestore | Alta**: Il sistema deve permettere a un nuovo utente di registrarsi (inserimento dati relativi al campo) e, durante l’onboarding scegliere in modo definitivo il ruolo “Gestore del Campo”, venendo reindirizzato alla configurazione della propria struttura sportiva (numero di campi, tariffe, orari di disponibilità).
- **RF_ACC_2 | RegistrazioneGiocatore | Alta**: Il sistema deve permettere a un nuovo utente di registrarsi (inserimento dati anagrafici) e, durante l’onboarding, scegliere in modo definitivo il ruolo “Giocatore”, configurando la propria Player Card (posizione, piede dominante, più aggiunta di dati anagrafici già definiti).

## Requisiti speciali

- **RNF_U_1 | OnboardingGiocatore | Alta**: L’intera procedura di iscrizione e configurazione iniziale (dalla generazione del profilo fino alla definizione della Player Card e all’assegnazione del ruolo) deve svolgersi senza assistenza esterna, garantendo un’esperienza rapida completabile in meno di 3 minuti (riferimento: le linee guida UX sull’onboarding mobile indicano che un processo di registrazione che supera i 3–5 minuti genera un abbandono significativo da parte dell’utente)
- **RNF_IMP_1 | VincoliTecnologici | Alta**: Il sistema deve essere sviluppato con il framework Flutter per l’interfaccia utente e con la piattaforma Supabase per il backend, che gestisce l'archiviazione dei dati e l'autenticazione degli utenti; le notifiche push sono inviate tramite Firebase Cloud Messaging.

## Tabella degli oggetti

- `Account` (Entity): Dati comuni, include ruoloAccount (Giocatore o GestoreCampo, distinto dalla posizione in campo), età, statoOnboarding, preferenzeNotifiche.
- `Giocatore` (Entity): Specializzazione di Account. Possiede ruoloPreferitoInCampo e piedeDominante. Le statistiche sono calcolate tramite query su Partecipazione e VotazioneMVP (senza Entity PlayerCard separata).
- `GestoreCampo` (Entity): Specializzazione di Account. Possiede idAccountPagamenti. Campi, tariffe e disponibilità sono raggiungibili tramite le associazioni.
- `RegistrazioneControl` (Control): Gestisce registrazione, scelta ruolo, configurazione Player Card e ripresa dell'onboarding. Per il Gestore, richiama GestioneCampiControl e DashboardGestore (definiti nella sezione Pagamenti).
- `FormRegistrazione` (Boundary): Raccoglie i dati anagrafici, email e password durante la registrazione (UI_2, passi 1-3 di UC_ACC_1).
- `FormOnboarding` (Boundary): Permette di scegliere il ruolo, Giocatore o Gestore del Campo (UI_3).
- `FormPlayerCard` (Boundary): Raccoglie i dati di configurazione della Player Card: ruolo in campo e piede dominante (UI_4).
- `Dashboard` (Boundary): Mostra la schermata principale dopo il login o il completamento dell’onboarding. Permette l'accesso alle proprie partite e alle partite pubbliche disponibili (bacheca).
