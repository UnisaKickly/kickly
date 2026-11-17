# Kickly – Task dell'SDD per la WBS e per il Gantt

Documento di lavoro del team 404 Team Not Found (C12), aggiornato al 16/11/2026 (ore 16:45), per la costruzione della WBS (versione successiva alla 1.0, che copre solo il RAD) e del diagramma di Gantt dell'SDD. Riguarda **solo l'SDD**; l'ODD parte dal 24/11/2026 e avrà un file analogo. I codici sono quelli della WBS: **1 = RAD, 2 = SDD**.

## 1. Riferimenti temporali

- L'avvio dei lavori sull'SDD è **martedì 10/11/2026** (Meeting n°4 su Teams). La consegna dell'SDD è **lunedì 23/11/2026**; l'ODD parte il **24/11/2026**.
- Consegna finale del progetto **04/12/2026**, preconsegna **30/11/2026** (SOW).
- Le date sono **indicative** fino alla lezione 2 di System Design (mapping HW/SW e dati persistenti), che non è ancora stata tenuta. Le sezioni 3.3 e 4 (gestione dei dati persistenti) partono dopo quella lezione.
- La struttura dell'SDD segue l'**indice fornito dai docenti**, riportato nel documento: 1 Introduzione (1.1–1.6); 2 Architettura del sistema corrente; 3 Architettura del sistema proposto (3.1 Panoramica; 3.2 Decomposizione in sottosistemi, con 3.2.1 Diagramma dei sottosistemi e 3.2.2 Diagramma architetturale; 3.3 Mapping hardware/software, con 3.3.1 Deployment diagram); 4 Gestione dei dati persistenti (4.1 Introduzione, con la scelta della tecnologia; 4.2 Class Diagram Ristrutturato); 5 Glossario. Work package, task e ore di questo file seguono quell'indice.
- Fino all'implementazione **non si lavora a sprint**: il piano è a scadenze interne per sezione. Il SOW cita ancora Scrum; il SOW non si modifica e lo Scrum riguarda solo l'implementazione.
- Calendario: autori scrivono entro la scadenza di ciascun task → i due PM rivedono a scalare da martedì 17/11 → commenti dei PM entro **domenica 22/11 ore 18:00** → correzioni degli autori entro **lunedì 23/11 ore 12:00** → consegna dell'SDD lunedì 23/11.
- **Solo Mario Celzo e Renato Mancino rivedono** l'SDD. I PM **non scrivono** nessuna sezione; i membri del team **non si rivedono tra loro**.
- Lo stato dei ticket della sezione 3 è quello di Jira al 16/11/2026 (ore 16:35). La sezione 9 riporta lo stato del documento SDD e le revisioni anticipate dal 10/11/2026 al 16/11/2026.

## 2. Work package dell'SDD

| Codice | Work package | Responsabile (accountable) | Inizio | Fine | Task | Ore |
|---|---|---|---|---|---|---|
| 2.1.1 | Obiettivo e panoramica | Francesco Nuzzolo | 10/11/2026 | 13/11/2026 | 1 | 2 |
| 2.1.2 | Design goal (12 in totale, 2 per ogni membro del team) | Tutti i 6 membri non PM | 10/11/2026 | 12/11/2026 | 6 | 12 |
| 2.1.3 | Trade-off tra design goal | Gabriele Karol Vicinanza | 12/11/2026 | 13/11/2026 | 1 | 2 |
| 2.1.4 | Definizioni, acronimi e riferimenti | Simona Sceral | 13/11/2026 | 16/11/2026 | 1 | 1 |
| 2.2.1 | Sistema corrente | Gabriele Karol Vicinanza | 10/11/2026 | 13/11/2026 | 1 | 4 |
| 2.3.1 | Panoramica dell'architettura proposta | Antonio Tolino | 10/11/2026 | 13/11/2026 | 1 | 2 |
| 2.3.2 | Decomposizione in sottosistemi e diagramma architetturale | Giuseppe Sarlo | 10/11/2026 | 16/11/2026 | 2 | 6 + da stimare (2.3.2.2) |
| 2.3.3 | Deployment diagram (mapping HW/SW) | Simona Sceral | 14/11/2026 | 18/11/2026 | 1 | 6 |
| 2.4.1 | Introduzione ai dati persistenti (4.1): scelta della tecnologia | Francesco Nuzzolo | 12/11/2026 | 16/11/2026 | 1 | 2 |
| 2.4.2 | Class Diagram ristrutturato (4.2) | Pietro Senatore (referente) e Francesco Nuzzolo | 12/11/2026 | 18/11/2026 | 1 | 6 (stima) |
| 2.5.1 | Glossario | Francesco Nuzzolo | 18/11/2026 | 21/11/2026 | 1 | 2 |
| 2.5.2 | Indice, revision history e coerenza degli ID | Pietro Senatore | 19/11/2026 | 21/11/2026 | 1 | 2 |
| 2.6.1 | Revisione dei Project Manager | Mario Celzo e Renato Mancino | 16/11/2026 | 22/11/2026 | 5 | 11 |
| 2.6.2 | Correzioni e consegna dell'SDD | Mario Celzo e Renato Mancino | 22/11/2026 | 23/11/2026 | 1 | 2 |

Il codice 2 = SDD, con i gruppi 2.1 Introduzione (SDD sez. 1); 2.2 Sistema corrente (sez. 2); 2.3 Sistema proposto (sez. 3); 2.4 Gestione dei dati persistenti (sez. 4); 2.5 Glossario, indice e coerenza (sez. 5); 2.6 Revisione dei PM e consegna.

## 3. Task di dettaglio

| Codice | Jira | Task | Responsabile | Inizio | Fine | Ore | Stato (Jira 16/11) |
|---|---|---|---|---|---|---|---|
| 2.1.1.1 | KCK-150 | SDD 1.1, 1.6 – [TEAM] Obiettivo del sistema e panoramica del documento | Francesco Nuzzolo | 10/11/2026 | 13/11/2026 | 2 | In revisione; la 1.6 va riscritta sul nuovo indice (vedi 9.12) |
| 2.1.2.1 | KCK-151 | SDD 1.2 – 2 design goal: Usabilità e Affidabilità (DG_1–DG_2) | Simona Sceral | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.2.2 | KCK-152 | SDD 1.2 – 2 design goal: Supportability e Usabilità (DG_3–DG_4) | Gabriele Karol Vicinanza | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.2.3 | KCK-153 | SDD 1.2 – 2 design goal: Prestazioni e Affidabilità (DG_5–DG_6) | Pietro Senatore | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.2.4 | KCK-154 | SDD 1.2 – 2 design goal: Prestazioni e Implementazione (DG_7–DG_8) | Giuseppe Sarlo | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.2.5 | KCK-155 | SDD 1.2 – 2 design goal: Interfacce e Affidabilità (DG_9–DG_10) | Francesco Nuzzolo | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.2.6 | KCK-156 | SDD 1.2 – 2 design goal: Legali e Packaging (DG_11–DG_12) | Antonio Tolino | 10/11/2026 | 12/11/2026 | 2 | In revisione |
| 2.1.3.1 | KCK-176 | SDD 1.3 – Trade-off tra design goal | Gabriele Karol Vicinanza | 12/11/2026 | 13/11/2026 | 2 | In revisione |
| 2.1.4.1 | KCK-177 | SDD 1.4–1.5 – Definizioni, acronimi e riferimenti | Simona Sceral | 13/11/2026 | 16/11/2026 | 1 | In revisione; potare gli acronimi non più usati (vedi 9.12) |
| 2.2.1.1 | KCK-157 | SDD 2 – [COPPIA Gabriele + Francesco] Architettura del sistema corrente | Gabriele Karol Vicinanza, Francesco Nuzzolo | 10/11/2026 | 13/11/2026 | 4 | In revisione |
| 2.3.1.1 | KCK-158 | SDD 3.1 – [TEAM] Panoramica dell'architettura proposta | Antonio Tolino | 10/11/2026 | 13/11/2026 | 2 | In revisione; revisione anticipata 12/11: testo da allineare alla 3.3 (Edge Functions, Realtime e FCM) |
| 2.3.2.1 | KCK-159 | SDD 3.2 – [COPPIA Giuseppe + Pietro] Decomposizione in sottosistemi e diagramma | Giuseppe Sarlo, Pietro Senatore | 10/11/2026 | 13/11/2026 | 6 | In revisione; 3.2 e diagramma 3.2.1 controllati il 12/11: a posto |
| 2.3.2.2 | KCK-189 | SDD 3.2.2 – [COPPIA Giuseppe + Pietro] Diagramma architetturale | Giuseppe Sarlo, Pietro Senatore | 11/11/2026 | 16/11/2026 | da stimare | In revisione; diagramma e testo controllati il 12/11: coerenti con RAD e 3.3 (3.2.2 chiusa); ore da stimare |
| 2.3.3.1 | KCK-160 | SDD 3.3 – [COPPIA Simona + Antonio] Deployment diagram | Simona Sceral, Antonio Tolino | 14/11/2026 | 18/11/2026 | 6 | In revisione; scritta in anticipo l'11/11; correzioni del 12/11 applicate e ricontrollate |
| 2.4.1.1 | KCK-190 | SDD 4.1 – Introduzione (scelta della tecnologia) | Francesco Nuzzolo | 12/11/2026 | 16/11/2026 | 2 | Da fare; testo presente nel documento del 16/11 (ACID e PostgreSQL), da riformulare (vedi 9.12) |
| 2.4.2.1 | KCK-161 | SDD 4.2 – [COPPIA Pietro + Francesco] Class Diagram ristrutturato | Pietro Senatore, Francesco Nuzzolo | 12/11/2026 | 18/11/2026 | 6 (stima) | In revisione; nel documento del 16/11 c'è solo una frase introduttiva, il diagramma va inserito |
| 2.5.1.1 | KCK-186 | SDD 5 – Glossario | Francesco Nuzzolo | 18/11/2026 | 21/11/2026 | 2 | Da fare |
| 2.5.2.1 | KCK-178 | SDD – Indice, revision history e coerenza degli ID con il RAD; revisione finale e consegna | Pietro Senatore | 19/11/2026 | 21/11/2026 | 2 | Da fare |
| 2.6.1.1 | KCK-187 | SDD – [PM] Revisione sezione 1 (introduzione, design goal, trade-off) | Mario Celzo | 16/11/2026 | 17/11/2026 | 2 | Da fare |
| 2.6.1.2 | KCK-188 | SDD – [PM] Revisione sezioni 2, 3.1 e 3.2 | Renato Mancino | 16/11/2026 | 17/11/2026 | 3 | Da fare |
| 2.6.1.3 | KCK-181 | SDD – [PM] Revisione sezioni 3.3 e 4.1 | Mario Celzo | 19/11/2026 | 19/11/2026 | 2 | Da fare |
| 2.6.1.4 | KCK-182 | SDD – [PM] Revisione sezione 4.2 (class diagram ristrutturato) | Renato Mancino | 21/11/2026 | 21/11/2026 | 2 | Da fare |
| 2.6.1.5 | KCK-184 | SDD – [PM] Revisione sezione 5 (glossario), indice e coerenza degli ID | Renato Mancino | 22/11/2026 | 22/11/2026 | 2 | Da fare |
| 2.6.2.1 | KCK-149 | SDD – [PM] Correzioni degli autori e consegna dell'SDD (commenti PM entro dom 22/11 ore 18:00; correzioni entro lun 23/11 ore 12:00) | Mario Celzo, Renato Mancino | 22/11/2026 | 23/11/2026 | 2 | Da fare |

**Totale ore SDD (stima): 60 h**, di cui **13 h dei Project Manager** (solo revisione e consegna). Le 6 h del Class Diagram ristrutturato (2.4.2.1) sono una stima nuova (il task era stato tolto dal piano e il capitolo 4 è stato reintrodotto il 16/11). Il totale non include ancora il task 2.3.2.2 (KCK-189, creato l'11/11), le cui ore sono da stimare.

Le ore sono una **stima di pianificazione** (come per il RAD: 116 h). Quando un task è a coppia, le ore sono il totale della coppia. Le ore effettive vanno prese da `9. RendicontazioneOre` a fine SDD, e la WBS va aggiornata con il consuntivo. Il SOW limita il progetto a 400 h (50 h per membro): RAD 116 h + SDD circa 60 h = circa 176 h, restano circa 224 h per ODD, pianificazione dei test, implementazione, test, manuali e chiusura.

## 4. Come ricavare le date reali da Jira (per i documenti)

Jira registra data e ora di ogni cambio di stato (**Da fare → In corso → In revisione → Fatto**) e la data di risoluzione. Al momento di aggiornare i documenti si leggono da Jira:
1. **Chi ha svolto cosa e quando**: la cronologia (changelog) di ogni ticket e il campo di risoluzione, con una ricerca JQL per l'epic System Design (KCK-4) e i suoi figli.
2. **Data di fine reale** = momento in cui il ticket passa a _Fatto_. Il ticket _In revisione_ vale come consegnato dall'autore; _Fatto_ vale come approvato dal PM.
3. **Ritardi** = data di fine reale – scadenza interna (campo "scadenza" del ticket).
Perché funzioni, **ogni membro deve spostare il proprio ticket quando finisce**, non tutti insieme alla fine: altrimenti le date reali risultano sbagliate. Da ricordare al Meeting n°4.

## 5. Milestone

| Data | Milestone |
|---|---|
| 10/11/2026 | Meeting n°4: avvio dell'SDD (Teams, ore 15:00) |
| 12/11/2026 | Consegna dei 12 design goal (sez. 1.2) |
| 13/11/2026 | Sezioni 1.1, 1.3, 2, 3.1, 3.2 consegnate dagli autori |
| 16/11/2026 | Diagramma architetturale (3.2.2) e introduzione ai dati persistenti con scelta della tecnologia (4.1) consegnati dagli autori |
| 17/11/2026 | Inizia la revisione dei PM (sezioni 1, 2, 3.1, 3.2) |
| 18/11/2026 | Deployment diagram (3.3) e class diagram ristrutturato (4.2) consegnati |
| 19/11/2026 | Revisione dei PM di 3.3 e 4.1 |
| 21/11/2026 | Glossario (sez. 5), indice e coerenza degli ID; revisione dei PM di 4.2 |
| 22/11/2026 ore 18:00 | Commenti dei PM completati |
| 23/11/2026 ore 12:00 | Correzioni degli autori; consegna dell'SDD |
| 24/11/2026 | Avvio dell'ODD |
| 30/11/2026 | Preconsegna |
| 04/12/2026 | Consegna finale |

## 6. Verifica rispetto al SOW (System Design)

| Elemento | Previsto dal SOW | Nei task dell'SDD |
|---|---|---|
| Design goal | 2–4 per membro del team | 2 per ciascuno dei 6 membri non PM = **12** (DG_1–DG_12) |
| Diagramma di decomposizione in sottosistemi | 1 per team, con descrizione e motivazione | 1 (task 2.3.2.1) |
| Diagramma architetturale (vista a strati) | Non indicato esplicitamente dal SOW; previsto dalla struttura dell'SDD (sez. 3.2.2) | 1 (task 2.3.2.2) |
| Deployment diagram | 1 per team, con descrizione e motivazione | 1 (task 2.3.3.1) |
| Design pattern | 1–2 | Nell'ODD, dal 24/11 |
| Impegno | ≤ 50 h × n membri (400 h) | SDD circa 60 h |

**Nota.** I design goal sono 12 e non 16 perché i PM non scrivono sezioni dell'SDD ma le rivedono; il SOW li conterebbe su tutti gli 8 membri (16–32 design goal). È una scelta del team da tenere presente in caso di richiesta dei docenti.

## 7. Documenti da aggiornare con l'SDD

| Documento | Cosa aggiornare | Quando |
|---|---|---|
| **SPMP** (`11. Project_Management_Plan`) → v1.1 | **Fatto il 09/11/2026 (v1.1)**: pianificazione dell'SDD (work package, ore, milestone), lavoro senza sprint fino all'implementazione, Jira al posto di Trello, ProjectLibre per il Gantt. Riallineato il 16/11/2026 all'indice dei docenti, con il capitolo 4 sui dati persistenti (SDD 60 h; versione non incrementata). Da aggiornare di nuovo con le date reali di Jira dopo la consegna dell'SDD (23/11) | Fatto; secondo aggiornamento dopo il 23/11 |
| **WBS** → v1.1 | Albero e WBS Dictionary del gruppo 2 (SDD) con ore e costi (PM 30 €/h, altri 20 €/h); poi gruppo 3 (ODD) | Ora (pianificato); consuntivo dopo il 23/11 |
| **Gantt** (`4. GANTT`) → `2_SDD` | Diagramma dell'SDD (PNG/PDF; il file ProjectLibre si esporta dopo) | Ora |
| **Status Report – Gate SDD** (KCK-29) | Avanzamento, ore, costi rispetto alla baseline; date reali | Alla consegna dell'SDD |
| **Rendicontazione ore** (`9.`) | Ore effettive di ogni membro per i task dell'SDD | Settimanale e a fine SDD |
| **Agende e minute** (`8.`) | Agenda (v1.0) e minuta (bozza v0.1) del Meeting n°4 (10/11) in `4_Meeting`: la minuta va completata durante e subito dopo il meeting. Riallineate il 16/11/2026 all'indice dei docenti, con il capitolo 4 (PDF riesportati) | Fatto in bozza; completare il 10/11 |
| **RACI** (`5.`), **Risk Management** (`2.`) | Responsabilità sui task dell'SDD; rischi specifici (lezione 2 non ancora tenuta, scadenze ravvicinate delle revisioni dei PM) | Prima della preconsegna |
| **Matrice di tracciabilità** | Collegamento RAD → SDD (sottosistemi e servizi) | A fine SDD / con l'ODD |

## 8. Note per chi aggiorna i documenti

- **Non usare** il linguaggio Scrum (sprint, sprint review, backlog di sprint) per RAD, SDD e ODD: fino all'implementazione non si lavora a sprint. Gli sprint compaiono solo nella fase di implementazione.
- Nei ticket dell'SDD i PM sono revisori: non assegnare loro sezioni di scrittura.
- Jira: progetto **KCK** (https://mariospaceforuni.atlassian.net). Epic: **KCK-4** System Design (SDD), **KCK-185** Object Design (ODD). Stati: Da fare / In corso / In revisione / Fatto.
- **Trello → Jira**: il SOW prescrive Jira per i task. Il 09/11/2026 la parola Trello è stata sostituita con Jira in tutti i documenti (Business Case, Analisi finanziaria, Team Contract, Scope/Requirements/Configuration Management Plan, SPMP, agende e minute 0–3).
- Restano da sistemare in Jira: gli sprint "Sprint 2 · SDD" e "Sprint 3 · ODD+test" della board e i ticket KCK-62/63/64 ("Status report – Gate ODD / Sprint 1 / Sprint 2"), che usano ancora la terminologia a sprint.
- Dipendenze: il diagramma architetturale (3.2.2, scadenza 16/11) dipende dalla decomposizione 3.2 (13/11); glossario e indice (21/11) seguono le sezioni 1, 2 e 3.

## 9. Stato dell'SDD e revisioni anticipate (dal 10/11/2026 al 16/11/2026)

La sera del 10/11/2026 Renato Mancino ha riletto le sezioni già scritte dagli autori nel file `Prodotto/2.SDD/Kickly_SDD_v1.0.docx` (1.1–1.6, 2, 3.1, 3.2) e le ha confrontate con il RAD v2.9, l'SDD di Esistere (C04), l'SDD di esempio (C17), la teoria (L15 System Design) e il SOW. Le correzioni sono comunicate agli autori con le scadenze della tabella; la revisione formale dei PM (KCK-187 e KCK-188, dal 16/11) prosegue come da piano sul testo corretto.

### 9.1 Stato delle sezioni e correzioni richieste

| Sezione | Ticket | Stato nel documento (10/11) | Correzioni richieste (sintesi) | Correzione entro |
|---|---|---|---|---|
| 1.1 Obiettivo | KCK-150 | Scritta | Riscrivere gli aspetti: un punto per attore (Organizzatore, Giocatore, Gestore del Campo) con problema e soluzione | 13/11 |
| 1.2 Design goal | KCK-151–156 | Scritta (12 DG) | Rank da 1 a 12 con tabella ordinata; DG_7 ricollegato a RNF_PRE_2; DG_8 riscritto da RNF_IMP_1; ID di DG_10; togliere le soglie non presenti nel RAD (DG_1, DG_3, DG_4, DG_10, DG_11) | 12/11 |
| 1.3 Trade-off | KCK-176 | Vuota (solo segnaposto) | Tabella "Trade-off / Descrizione" con 4 compromessi (Affidabilità vs Prestazioni; Sicurezza pagamenti vs Autonomia; GDPR vs Storico; Estensibilità vs Costo) | 13/11 |
| 1.4 Definizioni, acronimi | KCK-177 | Scritta | Aggiungere P e L e gli acronimi usati nel testo (CRUD, URI, JSON, IDE, MVC, PSTN, AD); togliere HTTPS se non usato | 16/11 |
| 1.5 Riferimenti | KCK-177 | Scritta | Citazione completa di Bruegge e Dutoit; versione e data di ogni documento; formattazione uniforme | 16/11 |
| 1.6 Panoramica | KCK-150 | Scritta | Riallineare i punti 2 e 3 ai titoli dell'indice dei docenti | 13/11 |
| 2 Sistema corrente | KCK-157 | Scritta (testo e diagramma) | "Sistema corrente" al posto di "As-Is"; nodi del testo uguali a quelli del diagramma; correggere il diagramma; paragrafo sulle criticità dal RAD; frase finale; rimando al RAD | 13/11 |
| 3.1 Panoramica | KCK-158 | Scritta | Stile Client/Server a strati (three-tier); Repository come design pattern del Data Layer (ODD); cosa gira lato server; motivazione con ID dei DG; togliere IDE ed emulatore | 13/11 |
| 3.2 Decomposizione | KCK-159 | Scritta (7 sottosistemi); manca il diagramma 3.2.1 | Dipendenze tra sottosistemi; correzioni di contenuto (leghe pubbliche o private, fornitore di pagamento); RNF_PRE_3 e RNF_A_1; motivazioni con ID dei DG; diagramma dei package UML con descrizione e motivazione | 13/11 |
| 3.3, 4.1 (allora 3.4.1) | KCK-160, KCK-190 | Non iniziate (segnaposto) | Non ancora in revisione | 18/11 (3.3); 16/11 (4.1) |
| 4.2 (allora 3.4.2) | KCK-161 | Non iniziata | Non ancora in revisione | 18/11 |
| 5 Glossario (allora 4) | KCK-186 | Vuota | Non ancora in revisione | 21/11 |

### 9.2 Effetto sulla WBS e sul Gantt

- **Nessun nuovo work package.** Le correzioni rientrano nei task degli autori (gruppi 2.1, 2.2 e 2.3.1–2.3.2) e la revisione anticipata nei task dei PM (2.6.1.1 e 2.6.1.2). Le ore di pianificazione erano 52 h a quella data (poi 60 h, vedi 9.12; la numerazione 3.4.1 di questa sezione è oggi 4.1); le ore reali delle correzioni si registrano sui ticket interessati e in `9. RendicontazioneOre`.
- **Date invariate**: le correzioni cadono dentro le scadenze interne già fissate (12/11, 13/11, 16/11).
- **Stato Jira.** Si suggerisce di riportare a "In corso" i ticket già in "In revisione" (KCK-151, 152, 153, 159) finché le correzioni non sono fatte, e di rimetterli in "In revisione" a correzione completata, così le date reali di Jira restano attendibili.

### 9.3 Criteri usati nella revisione

1. **Coerenza con il RAD v2.9**: codici degli RF e degli RNF, termini del Glossario, nomi dei sottosistemi e delle classi Control.
2. **Teoria (L15 System Design)**: design goal derivati dagli RNF e prioritizzati con un rank; trade-off; stili architetturali (client/server, three-tier, layering aperto e chiuso); coesione e accoppiamento; dipendenze tra sottosistemi.
3. **Indice dei docenti** (riportato nell'SDD) e **SDD di Esistere (C04) e di esempio (C17)**: struttura e contenuto delle sezioni.
4. **SOW**: 12 design goal, 1 diagramma di decomposizione e 1 deployment diagram con descrizione e motivazione, 1–2 design pattern nell'ODD.
5. **Regola sui design goal**: un design goal rispecchia il suo RNF del RAD e non aggiunge soglie (percentuali, tempi) che nel RAD non ci sono.

### 9.4 Decisioni e punti aperti

- **Rank proposto** (da confermare con il team, in base alle priorità del RAD): 1 DG_9, 2 DG_10, 3 DG_5, 4 DG_11, 5 DG_2, 6 DG_1, 7 DG_3, 8 DG_7, 9 DG_8, 10 DG_12, 11 DG_6, 12 DG_4.
- **Copertura degli RNF**: i 12 design goal coprono 12 dei 13 RNF del RAD; RNF_PRE_3 (rimborso entro 5 giorni lavorativi) non ha un design goal proprio ed è assegnato al sottosistema Strutture e Pagamenti.
- **Repository**: è un design pattern del Data Layer e va trattato nell'ODD (candidato ai 1–2 pattern richiesti dal SOW), non uno stile architetturale.
- **Prima pagina**: correggere due refusi nella tabella Team; la copertina riporta v1.0 del 03/11/2026 mentre la Revision History ha solo la riga 0.1 del 27/10/2026.
- **Segnaposto in corsivo** (`[SDD … · KCK-… · entro …]`): da rimuovere man mano che le sezioni sono completate.
- **RAD:** nella cartella 1.RAD c'è solo il PDF `Kickly_RAD_v2.9_1.docx.pdf`; il file .docx non c'è più (da confermare con Renato).

### 9.5 Seconda revisione anticipata (11/11/2026)

L'11/11/2026 Renato Mancino ha fatto una seconda revisione anticipata, dal capitolo 1 fino al 3.2 compreso, sul testo dell'SDD presente in `Prodotto/2.SDD` (Kickly_SDD_v1.0.pdf), confrontandolo con il RAD v2.9, la teoria (L15), l'SDD di Esistere (C04) e i ticket Jira. Le sezioni 3.3 e 3.4.1 sono ancora vuote e non sono state riviste. La prima revisione (10/11, punto 9.1) resta valida; questa la integra.

- **Capitolo 1:** coerente con il RAD (12 design goal su 13 RNF, ID corretti). Residui segnalati: DG_11 troncato, trade-off (1.3) ancora vuoto, refuso «1.1 modifiche» nel 1.1, citazione di Bruegge e versioni dei documenti nel 1.5, panoramica 1.6 da riallineare ai titoli dell'indice dei docenti.
- **Sezione 2:** da riscrivere a partire dal RAD §2.1 e dal Business Case (piattaforme già esistenti: Fubles, Playtomic, PrenotaUnCampo), senza riprendere formulazioni di altri documenti.
- **Sezione 3.1:** precisare cosa gira nell'app e cosa sul server (funzioni lato server per contatore RSVP, webhook di pagamento e cancellazione GDPR).
- **Sezione 3.2 (KCK-159):** nuova formulazione con frase introduttiva, elenco dei 7 sottosistemi nel formato «Nome: si occupa di…» e tabella di dettaglio (classi Control, requisiti, design goal, motivazione). Correzioni: RNF_A_1 da Persistenza a Voto MVP e Notifiche; RNF_PRE_3 e RF_ACC_1 a Strutture e Pagamenti; leghe pubbliche o private (non «gruppi chiusi»); nome della classe SicurezzaAccessiControl. Il testo è stato comunicato agli autori nei commenti di KCK-159.
- **Nuovo task KCK-189 (2.3.2.2):** «SDD 3.2.2 – Diagramma architetturale», subtask di KCK-148, Giuseppe Sarlo e Pietro Senatore, scadenza 16/11. Un solo diagramma con i 7 sottosistemi suddivisi in Presentation, Domain e Data (classi Boundary, Control e Repository con i nomi del RAD). La scadenza del 16/11 lascia il 3.2 completo prima della revisione dei PM del 17/11 (KCK-188).
- **Effetto su WBS e Gantt:** il task rientra nel work package 2.3.2 (nessun nuovo work package a sé), ma le sue ore sono da stimare e il totale va aggiornato di conseguenza. SPMP v1.1 e Gantt `2_SDD` vanno allineati quando si aggiorna la WBS.
- **Stato Jira:** all'11/11 KCK-159 risulta ancora «In revisione»; si suggerisce di riportarlo a «In corso» finché gli autori non hanno applicato le correzioni del 3.2.

### 9.6 Terza revisione anticipata (12/11/2026)

Il 12/11/2026 Renato Mancino ha rivisto in anticipo la sezione 3.3 Mapping Hardware/Software e il 3.3.1 Deployment diagram (KCK-160, Simona Sceral e Antonio Tolino), che gli autori hanno completato l'11/11 (commento di Simona su KCK-160 alle 19:35). La revisione è stata fatta sul testo di `Prodotto/2.SDD/Kickly_SDD_v1.0.pdf` (esportato il 12/11 alle 08:18), confrontandolo con il RAD v2.9, con gli altri documenti di progetto (Business Case, SPMP v1.1, minuta del meeting 4) e con la documentazione ufficiale di Supabase. Il 3.3 si aggiunge alle sezioni già riviste (capitolo 1, 2, 3.1 e 3.2); il 3.4.1 resta da rivedere.

- **Esito:** impianto corretto. Nodi, tecnologie (Flutter/Dart, Supabase con PostgreSQL e RLS, Auth, Realtime, Edge Functions, Stripe Connect, Firebase Cloud Messaging, servizio email) e protocolli (HTTPS, WSS, SMTP su TLS) sono coerenti con RAD e design goal, e i DG citati nel testo sono quelli giusti.
- **Notifiche:** confermato Firebase Cloud Messaging in tutti i documenti (RNF_IMP_1, Business Case, SPMP, minuta del meeting 4). Supabase non ha una push nativa (il Realtime vale a app aperta), quindi la catena evento → Edge Function → FCM è corretta.
- **Correzioni al testo del 3.3:** accorciare (da circa 400 a circa 250 parole) e togliere ogni riferimento a design goal, sezioni e sottosistemi; non scrivere «a tre livelli» (gli strati sono tutti sul telefono e il server è un BaaS); aggiungere l'invio delle email tra le Edge Functions; usare «servizio email» (nome del RAD) invece di «server di posta (SMTP)»; aggiungere una frase di motivazione (servizio gestito al posto di un server proprio, chiave segreta di Stripe solo lato server), richiesta dal SOW; uniformare il grassetto. Il testo sostitutivo è stato preparato da Renato.
- **Correzioni al deployment diagram:** aggiungere il componente «Invio email di allerta»; rinominare il nodo in «Servizio Email» con collegamento HTTPS (API) dalle Edge Functions, perché da Supabase le Edge Functions non possono usare le porte SMTP in uscita (da verificare in implementazione); esportare il diagramma in alta risoluzione; aggiornare la tabella 3.3.1 e aggiungere la frase introduttiva.
- **Punti aperti emersi dalla revisione:**
  - il token FCM non ha un attributo nel RAD (DispositivoRegistrato): da prevedere nell'ODD (`token_fcm`);
  - il 3.2.2 era ancora senza diagramma (KCK-189);
  - rischio: per le push su iPhone FCM passa da APNs, che richiede un account Apple Developer a pagamento, mentre l'SPMP non prevede acquisti; da decidere se dimostrare le push solo su Android;
  - il ticket KCK-160 chiedeva anche le specifiche hardware e software minime (come nel C17): non sono nel testo e, per tenere la sezione breve, si propone di non richiederle.
- **Comunicazione agli autori:** le correzioni sono nel commento su KCK-160 che Renato pubblica di persona. Dopo averle applicate, Simona sposta il ticket in «In revisione».
- **Stato Jira:** KCK-160 è «In corso» (verificato il 12/11).
- **Effetto su WBS e Gantt:** nessuna variazione di date. KCK-160 resta 14–18/11 (consegnata in anticipo) e la revisione formale dei PM (KCK-181, Mario Celzo, 19/11) resta il controllo finale.

### 9.7 Quarta revisione anticipata (12/11/2026): 3.2.2 Diagramma architetturale (KCK-189)

Il 12/11/2026 (PDF dell'SDD esportato alle 11:51) Renato Mancino ha rivisto in anticipo il testo e il diagramma della sezione 3.2.2 (KCK-189, coppia Giuseppe Sarlo + Pietro Senatore), confrontandoli con il RAD v2.9 (sezione 3.4.4.1, tabelle degli oggetti), con 1.2 (DG_8 e DG_9), 3.1, 3.2 e 3.3.

- **Conforme al RAD:** i nomi delle classi Boundary e Control di tutti i sei sottosistemi, la separazione per attore in Strutture e Pagamenti (DashboardGestore e GestioneCampiControl per il Gestore; InterfacciaPagamento e GestioneTransazioniControl per il Giocatore), la chiamata di RegistrazioneControl verso GestioneCampiControl all'onboarding del Gestore, e i riferimenti a DG_8 (accesso agli SDK confinato nel Data Layer) e DG_9 (dati di pagamento delegati a Stripe).
- **Entity non coerenti con il RAD nel diagramma:** «Utente» e «ProfiloGiocatore» (nel RAD: Account, Giocatore, GestoreCampo); «Invito» (nel RAD il codice di invito è assorbito da Lega); «Condivisione» e «LogSicurezza» (nel RAD: DispositivoRegistrato); manca Quota in Strutture e Pagamenti. Nei repository ci sono sia UtenteRepository sia AccountRepository, e manca un repository per le entità del dispositivo.
- **Servizi esterni:** nel diagramma PaymentGatewayAdapter, FCMAdapter ed EmailServiceAdapter stanno nel Data Layer sul telefono, mentre la 3.3 dice che Stripe, notifiche ed email passano dalle Edge Functions e che la chiave Stripe resta solo lato server. Il RAD li chiama GatewayPagamenti e ServizioEmail. Va chiarito che gli adapter chiamano le Edge Functions e va aggiunto il riquadro Edge Functions.
- **Testo:** togliere «(Giuseppe e Pietro)»; «three-tier» nel 3.1 è usato anche da Esistere, quindi può restare; in alternativa, dato che i tre livelli sono strati dentro l'app e fisicamente i livelli sono due (app e Supabase), si può scrivere «a strati»; la lista delle Edge Functions del 3.1 (contatore RSVP, cancellazione GDPR) va allineata alla 3.3 (pagamenti, notifiche, email).
- **Altro:** il diagramma è troppo piccolo nel PDF; manca il diagramma dei sottosistemi nel 3.2.1 (KCK-159); l'indice riporta «3.2.1 Diagramma di decomposizione» e non elenca il 3.2.2.
- **Comunicazione agli autori:** testo da girare dopo che Renato lo ha approvato; il commento su Jira lo pubblica Renato.
- **Confronto con Esistere (3.2.1 e 3.2.2):** Esistere ha un diagramma dei sottosistemi come component diagram con le dipendenze tra sottosistemi e, nel 3.2.2, un diagramma a strati in cui ogni classe è un componente separato (GUI, Control, Service, DAO), senza Entity e senza servizi esterni; il testo è breve (elenco degli strati e tre scelte per sottosistema). Kickly ha lo stesso impianto di testo e le stesse scelte per sottosistema; si discosta perché mette negli strati liste di nomi dentro un riquadro per sottosistema, include le Entity e i servizi esterni, e non ha il diagramma dei sottosistemi. Si propone di disegnare ogni classe come componente (come Esistere), togliere le Entity dal diagramma (restano nel RAD) e aggiungere il diagramma dei sottosistemi con le dipendenze.

### 9.8 Controllo 3.4.1 Scelta della tecnologia (12/11/2026; oggi sezione 4.1, vedi 9.12)

Il 12/11/2026 Renato Mancino ha confrontato il 3.4.1 scritto da Francesco (KCK-190) con quello di Esistere e con il resto dell'SDD. **Esito:** coerente. La struttura è la stessa (frase iniziale, quattro proprietà ACID, altri vantaggi, scelta di PostgreSQL); i riferimenti DG_10, DG_5, DG_2, DG_11, DG_8 e DG_9 corrispondono ai design goal della sezione 1.2, e Supabase, Realtime ed Edge Functions sono coerenti con la 3.3. Osservazioni minori: il testo è circa il doppio di quello di Esistere (si può accorciare); i nomi delle proprietà ACID non sono in grassetto; il rimando al paragrafo 3.5 per le policy RLS va tolto, perché la sezione 3.5 non è nell'indice dei docenti; nel documento c'è un grande spazio vuoto con interruzione di pagina a metà del primo punto elenco.

### 9.9 Controllo 3.2 e diagramma dei sottosistemi 3.2.1 (12/11/2026, ore 12:14)

Il 12/11/2026 Renato Mancino ha controllato la sezione 3.2 Decomposizione in sottosistemi e il nuovo diagramma 3.2.1 che Giuseppe Sarlo e Pietro Senatore (KCK-159) hanno aggiunto al documento. Il controllo è stato fatto su uno screenshot del Google Doc (il PDF in cartella è ancora quello delle 11:51, senza il diagramma): in un secondo screenshot ingrandito il diagramma è visibile per intero.

- **Testo 3.2:** è quello già corretto l'11/11 (frase introduttiva, elenco dei 7 sottosistemi nel formato «Nome: si occupa di…», leghe pubbliche o private, fornitore esterno di pagamento). Non c'è la tabella di dettaglio proposta l'11/11; come in Esistere basta l'elenco, quindi non è un problema.
- **Diagramma 3.2.1:** component diagram con i sette sottosistemi (Gestione Utenza, Leghe e Inviti, Partite e RSVP, Voto MVP e Notifiche, Strutture e Pagamenti, Rete Sociale e Sicurezza, Persistenza) e frecce di dipendenza tratteggiate verso Persistenza. Le dipendenze visibili sono coerenti con il RAD e con il 3.2.2 (Utenza → Strutture e Pagamenti per l'onboarding del Gestore, Leghe → Partite, Partite → Strutture e → Voto MVP). Controllo sul diagramma intero: tutti i sei sottosistemi hanno la freccia verso Persistenza; le altre dipendenze sono Utenza → Rete Sociale e Sicurezza, Utenza → Strutture e Pagamenti, Leghe → Partite, Leghe → Voto MVP e Notifiche (dashboard della lega con classifica e statistiche), Rete Sociale → Partite, Partite → Strutture, Partite → Voto MVP e Strutture → Voto MVP. Sono tutte giustificabili con il RAD; la freccia Leghe → Voto MVP va solo spiegata dagli autori se richiesto. Stile identico a Esistere (component diagram con frecce tratteggiate).
- **Da sistemare:** l'icona a forma di stella sopra «Persistenza» nel primo screenshot era un elemento dell'editor e non è nel diagramma; grande spazio vuoto con interruzione di pagina dopo il terzo punto elenco; l'indice, aggiornato nel documento del 16/11, riporta «3.2.1 Diagramma dei sottosistemi».
- **Stato:** KCK-159 da portare a «Fatto» dopo la revisione formale dei PM (revisione di Renato, KCK-188) (diagramma già controllato per intero).

### 9.10 Controllo del capitolo 3 (12/11/2026, ore 12:30)

Il 12/11/2026 Renato Mancino ha controllato il capitolo 3 dell'SDD (PDF esportato alle 12:27, scaricato dal Google Doc aggiornato) da 3.1 a 3.3.1, con i diagrammi 3.2.1, 3.2.2 e 3.3.1.

- **Coerente:** 3.1, 3.2 e 3.2.1 (sette sottosistemi con dipendenze); 3.3 con il deployment diagram aggiornato (componente «Invio email di allerta», HTTPS API verso il servizio email dalle Edge Functions, SMTP (TLS) solo da Supabase Auth); 3.4.1 nella versione breve.
- **3.2.2 da correggere (poi corretto, vedi 9.11):** (1) LinkCondivisoRepository non ha né entity nel RAD né tabella (linkCondivisione è un attributo di Partita): va tolto; (2) la frase «un Repository per ciascuna Entity del RAD» non è esatta, perché Giocatore e GestoreCampo sono gestiti da AccountRepository; (3) ServizioEmail e GatewayPagamenti stanno nello strato Data sul telefono, ma secondo la 3.3 l'email parte dalle Edge Functions e da Supabase Auth (il telefono non la raggiunge): il testo del terzo punto va riscritto di conseguenza.
- **Altre correzioni:** nel 3.1 la lista delle Edge Functions («contatore RSVP, cancellazione GDPR») va allineata alla 3.3 (pagamenti, notifiche, email); dal 3.3.1 sono state tolte la tabella e la frase introduttiva (non richieste).

### 9.11 Riepilogo delle revisioni anticipate

| Sezione | Ticket | Esito della revisione | Cosa resta da fare |
|---|---|---|---|
| 3.1 Panoramica | KCK-158 | Impianto corretto | Allineare le Edge Functions (contatore RSVP, pagamenti, notifiche, email, cancellazione account) e distinguere Realtime (aggiornamento) da FCM (push); testo allineato già fornito |
| 3.2 e 3.2.1 | KCK-159 | A posto: testo corretto, diagramma dei sottosistemi con sette sottosistemi e dipendenze coerenti | Spazio vuoto a fine pagina |
| 3.2.2 Diagramma architetturale | KCK-189 | Diagramma e testo corretti e coerenti con RAD e 3.3 (chiuso il 12/11) | Stimare le ore del task |
| 3.3 e 3.3.1 | KCK-160 | Correzioni applicate; deployment diagram corretto (Invio email di allerta, HTTPS API, SMTP solo da Auth) | Nessuna; tabella 3.3.1 e frase introduttiva tolte (non richieste) |
| 3.4.1 Scelta della tecnologia | KCK-190 | Coerente con i design goal e con la 3.3 | Applicare la versione breve con grassetto, togliere il rimando al 3.5 e reinserire il testo nel documento |

**Riferimenti usati:** RAD v2.9 (PDF aggiornato alle 11:55), SDD esportato alle 12:27, SDD di Esistere, L15. **Documenti collegati aggiornati:** agenda e minuta del Meeting 4 e SPMP v1.1 (sezione 9.12). **Comunicazione agli autori:** commenti da pubblicare su Jira a cura di Renato (KCK-160, KCK-189, KCK-190); nessun commento è stato pubblicato da Claude. **Revisione formale dei PM:** KCK-181 (Mario, 19/11) resta il controllo finale su 3.3 e 3.4.1.

**Aggiornamento ore 12:42 – 3.2.2 (KCK-189):** Renato Mancino ha ricevuto il diagramma architetturale corretto (file `diagramma_architetturale_corretto`) e l'ha controllato: tolti LinkCondivisoRepository e ServizioEmail, DispositivoRepository al posto del repository di sicurezza, GatewayPagamenti nello strato Data senza collegamento a Persistenza, un repository per ciascuna delle 13 entity del RAD (Giocatore e GestoreCampo tramite AccountRepository), «use» onboarding Gestore da GestioneUtenzaControl a GestioneStruttureControl. **Esito: il diagramma va bene.** Resta da riscrivere il testo del 3.2.2 (punto sui servizi esterni e frase sui Repository) perché sia coerente con il diagramma; nome facoltativo: DispositivoRegistratoRepository, come l'entity del RAD.

**Aggiornamento ore 12:47 – 3.2.2 (KCK-189):** il testo del 3.2.2 riscritto dagli autori è stato controllato da Renato Mancino ed è coerente con il diagramma corretto, con la 3.3 e con il RAD. Applicati due ritocchi: «sei sottosistemi di gestione» (Persistenza non è divisa in GUI, Control e Repository) e la frase sulla ricezione delle notifiche tramite l'SDK di Firebase Cloud Messaging nello strato Data. **Con diagramma e testo allineati, il 3.2.2 si può considerare chiuso**; restano solo le ore di KCK-189 da stimare.

### 9.12 Allineamento all'indice dei docenti (16/11/2026, aggiornato ore 16:45)

Il 16/11/2026 (ore 15:30) Renato Mancino ha caricato l'SDD aggiornato (`Prodotto/2.SDD/Kickly_SDD_v1.0.pdf`, 14 pagine). Nel primo allineamento di quel pomeriggio l'indice era stato letto come «3.4 Gestione dei dati persistenti» e «4 Glossario». **Correzione di Renato (ore 16:30):** il capitolo **4 Gestione dei dati persistenti** (4.1 Introduzione, 4.2 Class Diagram Ristrutturato) fa parte dell'indice e va scritto; il Glossario è il capitolo **5**. L'indice fornito dai docenti, riportato nel documento, è quindi: 1 Introduzione (1.1 Scopo del sistema, 1.2 Design Goals, 1.3 Trade-off, 1.4 Definizioni, acronimi e abbreviazioni, 1.5 Riferimenti, 1.6 Panoramica del documento); 2 Architettura del Sistema corrente; 3 Architettura del Sistema proposto (3.1 Panoramica; 3.2 Decomposizione in sottosistemi: 3.2.1 Diagramma dei sottosistemi, 3.2.2 Diagramma Architetturale; 3.3 Mapping Hardware/Software: 3.3.1 Deployment Diagram); 4 Gestione dei dati persistenti (4.1 Introduzione, 4.2 Class Diagram Ristrutturato); 5 Glossario. L'indice automatico del Google Doc è ancora quello vecchio (3.4, 3.4.1 e «4.Glossario») e va aggiornato (KCK-178).

- **Mappa della numerazione:** 3.4.1 Scelta della tecnologia → **4.1 Introduzione** (KCK-190); 3.4.2 Class Diagram ristrutturato → **4.2** (KCK-161, ripristinato); 4 Glossario → **5** (KCK-186). Le sezioni 3.4.3, 3.4.4, 3.5, 3.6, 3.7 e il capitolo «Servizi dei sottosistemi» non sono nell'indice: i ticket KCK-179, 180, 183 e 191 restano marcati `da-eliminare`.
- **Documenti riallineati a questo indice:** task di Jira (epic KCK-4), questo file, SPMP v1.1 (work package, ore e milestone: SDD 60 h, di cui 13 dei PM; restano circa 224 h su 400), agenda e minuta del Meeting 4 (righe delle azioni, struttura dell'SDD al punto I[2] e P[2.1], dipendenza A[2.1.2], presentazione dei task P[5.1]). I PDF di SPMP, agenda, minuta e WBS sono stati riesportati il 16/11; la versione dell'SPMP non è stata incrementata.
- **Stato del documento al 16/11 (da sistemare con gli autori):**
  - il capitolo 4 è nel corpo del documento: 4.1 contiene il testo sulle proprietà ACID e su PostgreSQL, molto vicino a quello di Esistere (da riformulare), e 4.2 contiene solo una frase introduttiva, senza diagramma: il Class Diagram ristrutturato (KCK-161) va inserito;
  - la 1.6 Panoramica descrive ancora quattro capitoli, con il capitolo 3 che include i dati persistenti: va riscritta sui cinque capitoli dell'indice (KCK-150); testo proposto qui sotto;
  - nella Revision History la riga 1.4 «Ristrutturazione Class Diagram» **resta**, perché il class diagram è di nuovo nell'indice (KCK-178 controlla che la riga sia coerente con il contenuto);
  - «5. Glossario» è scritto come testo in grassetto e non come titolo di primo livello: va portato a Titolo 1 (KCK-186 e KCK-178);
  - 1.4 Acronimi: PK, FK, NN, CRUD, URI, CSV, IP e OS compaiono solo nella lista e non nel testo attuale; da togliere o da giustificare (KCK-177). DBMS, ACID e GUI sono usati nel capitolo 4 e vanno tenuti o aggiunti.
- **Testo proposto per la 1.6:**
  - Il presente documento è strutturato nel modo seguente:
  - 1. **Introduzione:** delimita lo scopo del sistema, definisce i design goals che guidano le scelte progettuali e i trade-off accettati tra di essi, e riporta definizioni, acronimi, abbreviazioni e riferimenti utilizzati nella stesura del documento.
  - 2. **Architettura del sistema corrente:** esamina dal punto di vista architetturale gli strumenti su cui poggia oggi l'organizzazione delle partite amatoriali, chiarendo in che misura sia possibile ricavarne un'architettura software di riferimento.
  - 3. **Architettura del sistema proposto:** descrive l'architettura di Kickly attraverso una panoramica dello stile architetturale adottato, la decomposizione in sottosistemi con il diagramma dei sottosistemi e il diagramma architetturale, e il mapping hardware/software con il relativo deployment diagram.
  - 4. **Gestione dei dati persistenti:** motiva la scelta della tecnologia per la persistenza dei dati e presenta il class diagram ristrutturato delle entità del sistema.
  - 5. **Glossario:** raccoglie i termini tecnici e specialistici impiegati nel documento, corredati dalla relativa definizione.
- **Effetto su WBS e Gantt:** il work package 2.4 (gestione dei dati persistenti) ha due task, 4.1 (2 h) e 4.2 (6 h, stima); il glossario e l'indice sono nel gruppo 2.5 e la revisione dei PM nel gruppo 2.6, con 5 task di revisione (11 h; KCK-182 per il 4.2) più la consegna (2 h). Totale SDD 60 h (47 h degli autori, 13 h dei PM). Il Gantt `2_SDD` va costruito direttamente su questa struttura.
