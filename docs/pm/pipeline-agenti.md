# Pipeline con gli agenti su GitHub

Come Kickly applica le linee guida del corso "Agentic Workflow" (SeSa Lab):
un workflow deciso dai PM, agenti dentro i singoli passi, approvazioni di
persone in punti precisi. Le regole per gli agenti stanno in
[`AGENTS.md`](../../AGENTS.md); il flusso Git/Jira in
[`CONTRIBUTING.md`](../../CONTRIBUTING.md).

**Jira e GitHub.** Lo stato del progetto si segue su **Jira** (board KCK): la
vista che le linee guida affidano a GitHub Projects per noi e' Jira, collegata a
GitHub con l'app GitHub for Atlassian. Su GitHub l'issue "Task per agente" serve
solo ad **avviare gli agenti**: il titolo inizia con la chiave Jira
(`KCK-235: ...`), cosi' branch, commit e PR finiscono nel pannello Sviluppo del
ticket.

## 1. Il giro completo di un task

| # | Chi | Gesto | Cosa parte | Risultato |
|---|---|---|---|---|
| 0 | Agente (in locale, sola lettura) | Controllo di coerenza dei modelli (KCK-221) | - | Incoerenze tra caso d'uso, sequence, class diagram e category partition, decise dal team prima di implementare |
| 1 | PM | Apre l'issue con il modulo **Task per agente** | - | Issue con label `task-agente` |
| 2 | PM | Aggiunge `fase:piano` | `piano.yml` | Commento "## Piano" sull'issue |
| 3 | Sviluppatore | Rilegge il piano; se serve scrive `@claude ...` | `agente.yml` | Piano corretto |
| 4 | Sviluppatore | Commenta "piano approvato da <nome>" e aggiunge `fase:implementazione` | `implementa.yml` | Branch `feature/KCK-<n>-issue<m>` e PR in bozza |
| 5 | Sviluppatore | Aggiunge `fase:test` alla PR | `test.yml` | Commit con un test per ogni test frame |
| 6 | Sviluppatore | Prova in locale e segna la PR **Ready for review** | `ci.yml`, `revisione.yml` | Esito CI e commento del revisore |
| 7 | Compagno diverso dall'autore (e code owner) | Approva | Regole del branch | Merge consentito |
| 8 | Autore | Squash and merge, ticket Jira in Fatto | - | Issue chiusa da "Closes #m" |

Chi preferisce lavorare in locale (Claude Code o Copilot nell'editor) segue gli
stessi passi a mano: la procedura e' nella sezione "Procedura con l'agente" di
ogni ticket Jira. I due modi si possono combinare.

## 2. File della pipeline

| File | A cosa serve |
|---|---|
| `AGENTS.md`, `CLAUDE.md` | Istruzioni comuni: stack, comandi, regole sempre / chiedi prima / mai, quando un task e' finito |
| `.claude/agents/tester.md`, `revisore.md` | Ruoli in contesto separato |
| `.github/ISSUE_TEMPLATE/task-agente.yml`, `bug.yml`, `config.yml` | Moduli obbligatori per le issue |
| `.github/workflows/etichette.yml` | Crea le label `task-agente`, `fase:*`, `bug`, `prova` (lancio manuale) |
| `.github/workflows/saluto.yml` | Prova della pipeline con la label `prova` |
| `.github/workflows/piano.yml`, `implementa.yml`, `test.yml`, `revisione.yml`, `agente.yml` | Le fasi con gli agenti |
| `.github/workflows/ci.yml` | Nome del branch, DG9, avvisi su test e dipendenze modificati, tracciabilita' dei test frame, format/analyze/test, build web |
| `.github/workflows/copilot-setup-steps.yml` | Variante Copilot coding agent |
| `.github/pull_request_template.md`, `.github/CODEOWNERS` | Tracciabilita' nella PR e approvazioni obbligatorie |
| `scripts/tracciabilita.sh` | Tabella test frame -> test (anche nel riepilogo della CI) |
| `docs/fonti/` | RAD v2.9 e SDD v1.0 originali, da cui si ricavano i file di testo in `docs/` |

Limiti fissati nei workflow: un agente alla volta per issue/PR, `--max-turns`
(15-40) e `timeout-minutes` (15-45) per fase, tool ammessi elencati con
`--allowedTools`, nessun agente avviato da utenti esterni o da PR di fork.

## 3. Lista di controllo prima di dare il repository al team

Le voci con la spunta sono gia' nel repository. Le altre sono impostazioni di
GitHub o della console Anthropic che solo un PM amministratore puo' fare.

**Repository e file**
- [x] Struttura `docs/rad/uc`, `docs/modelli`, `docs/sdd`, `docs/test` (i contenuti arrivano dai ticket dello Sprint 1)
- [x] `AGENTS.md`, `CLAUDE.md` con `@AGENTS.md`, `tester.md`, `revisore.md`
- [x] Modulo "Task per agente" e `blank_issues_enabled: false`
- [x] Workflow delle fasi, CI e template della PR su `develop` (branch predefinito)
- [ ] Settings -> Collaborators: tutti i membri con ruolo **Write**

**Label**
- [ ] Actions -> "Crea le label della pipeline" -> Run workflow; poi controllare Issues -> Labels

**Secret, app e permessi**
- [ ] console.anthropic.com: account del team gestito dai PM, chiave API dedicata a questo repository e **limite di spesa mensile** (Limits)
- [ ] Settings -> Secrets and variables -> Actions -> New repository secret `ANTHROPIC_API_KEY` (mai nel codice, nei commenti o in chat)
- [ ] github.com/apps/claude -> Install -> **Only select repositories** -> `UnisaKickly/kickly`
- [ ] Settings -> Actions -> General -> Workflow permissions: **Read repository contents and packages permissions** e **Allow GitHub Actions to create and approve pull requests**

**Regole su `main` e `develop`** (Settings -> Rules -> Rulesets, oppure Branches)
- [ ] Require a pull request before merging, **1 approvazione**, Dismiss stale approvals, **Require review from Code Owners**
- [ ] Require status checks: "Nome del branch", "Controlli DG9 e test modificati", "Formattazione, analisi e test"
- [ ] Block force pushes, Restrict deletions
- [ ] **Nessun bypass** per gli amministratori: anche i PM passano dall'approvazione di un'altra persona
- [ ] Aprendo `.github/CODEOWNERS` su GitHub non compaiono errori (utenti con accesso Write)

**Prova**
- [ ] Issue di prova con label `prova` -> compare il commento del workflow "Saluto"
- [ ] Issue "Task per agente" di prova con `fase:piano` -> compare il piano

## 4. Problemi tipici

| Sintomo | Causa probabile | Dove guardare |
|---|---|---|
| Il workflow non compare in Actions | File non su `develop` o fuori da `.github/workflows/` | Branch predefinito |
| Job "skipped" | Nome della label diverso da quello nella riga `if:` | Issues -> Labels |
| Errore di autenticazione con l'API | Secret mancante o con altro nome | Settings -> Secrets |
| L'agente non commenta o non fa push | App non installata o permessi del job mancanti | Blocco `permissions`, Settings -> Actions |
| L'agente dice di non poter eseguire un comando | Comando non in `--allowedTools` | Log dello step dell'agente |
| La PR dell'agente non avvia la CI | Azioni fatte con `github.token` non avviano workflow | Segnare la PR Ready for review |
| Merge possibile con CI rossa o senza approvazione | Regole non attive o bypass consentito | Settings -> Rules |
| Il run si ferma prima di finire | Timeout o `--max-turns` | Fine del log: rivedere il task prima di alzare i limiti |

## 5. Metriche (servono a migliorare il processo, non a valutare le persone)

| Metrica | Dove si legge |
|---|---|
| PR accettate senza modifiche sostanziali | Revisioni con Approve al primo giro |
| Giri di revisione per PR | Richieste di modifica nella PR |
| Test frame coperti | Riepilogo CI, sezione "Tracciabilita' test frame" |
| Fallimenti della CI al primo push | Checks della PR |
| Tentativi dell'agente, agente interrotto | Template della PR |
| Modifiche ai modelli durante l'implementazione | PR che toccano `docs/modelli` |

## 6. Definition of Done di un task svolto con agenti

Piano approvato prima dell'implementazione; nomi del class diagram e dipendenze
dell'SDD rispettati (controllati dal revisore); un test per ogni test frame e
CI verde; nessun test esistente modificato senza motivo scritto nella PR;
nessuna dipendenza nuova non approvata da un PM; modelli aggiornati nella stessa
PR; PR con RF/UC, artefatti e revisore; approvazione di un membro diverso
dall'autore; l'autore sa spiegare il codice.
