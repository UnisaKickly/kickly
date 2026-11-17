# Lavorare con gli agenti

Come Kickly applica le linee guida del corso "Agentic Workflow" (SeSa Lab):
un workflow deciso dai PM, agenti dentro i singoli passi, approvazioni di
persone in punti precisi. Le regole per gli agenti stanno in
[`AGENTS.md`](../../AGENTS.md); il flusso Git/Jira in
[`CONTRIBUTING.md`](../../CONTRIBUTING.md).

**Niente agenti automatici su GitHub.** Il progetto non usa agenti che girano
dentro GitHub Actions (richiederebbero una chiave API a pagamento). Gli agenti
si usano:

- **in locale**, nell'editor o nel terminale (Claude Code, Copilot in VS Code,
  altri assistenti): leggono `AGENTS.md` / `CLAUDE.md` e i file in `docs/`;
- **come Copilot coding agent** su GitHub (incluso nel GitHub Student Developer
  Pack): prepara l'ambiente con `.github/workflows/copilot-setup-steps.yml`.

In tutti i casi il codice arriva su `develop` solo con una PR che passa la CI e
viene approvata da una persona.

**Jira e GitHub.** Lo stato del progetto si segue su **Jira** (board KCK),
collegata a GitHub con l'app GitHub for Atlassian: branch, commit e PR con la
chiave `KCK-<n>` finiscono nel pannello Sviluppo del ticket. Su GitHub le issue
servono solo per segnalare bug (modulo **Bug**).

## 1. Il giro completo di un task

| # | Chi | Gesto | Risultato |
|---|---|---|---|
| 0 | Team (con un agente in sola lettura) | Controllo di coerenza dei modelli (KCK-221) | Incoerenze tra caso d'uso, sequence, class diagram e category partition, decise dal team prima di implementare |
| 1 | Sviluppatore | Prende il ticket su Jira e crea il branch `<tipo>/KCK-<n>-...` da `develop` aggiornato | Branch collegato al ticket |
| 2 | Sviluppatore + agente | Chiede all'agente un **piano** (nessun file modificato), seguendo la sezione "Procedura con l'agente" del ticket | Piano scritto |
| 3 | Persona indicata nel ticket | Approva il piano; il nome va nella PR ("Piano approvato da") | Via libera all'implementazione |
| 4 | Agente, rivisto dallo sviluppatore | Implementa solo l'ambito approvato | Codice sul branch |
| 5 | Agente tester (`.claude/agents/tester.md`) o sviluppatore | Scrive un test per ogni test frame (TF) del ticket | Test nel branch |
| 6 | Sviluppatore | `dart format .`, `flutter analyze`, `flutter test` in locale; agente revisore (`.claude/agents/revisore.md`) | Controlli verdi, esito del revisore |
| 7 | Sviluppatore | Apre la PR verso `develop` con il template compilato; ticket Jira in **In revisione** | CI sulla PR |
| 8 | Compagno diverso dall'autore (code owner se la PR tocca file con proprietario) | Revisiona e approva | Merge consentito dalle regole del branch |
| 9 | Autore | **Squash and merge**, ticket Jira in **Fatto** | Lavoro su `develop` |

## 2. File che servono al lavoro con gli agenti

| File | A cosa serve |
|---|---|
| `AGENTS.md`, `CLAUDE.md` | Istruzioni comuni: stack, comandi, regole sempre / chiedi prima / mai, quando un task e' finito |
| `.claude/agents/tester.md`, `revisore.md` | Ruoli in contesto separato (tester e revisore) da usare in locale |
| `.github/workflows/copilot-setup-steps.yml` | Ambiente per il Copilot coding agent |
| `.github/workflows/ci.yml` | Nome del branch, DG9, avvisi su test e dipendenze modificati, tracciabilita' dei test frame, format/analyze/test, build web |
| `.github/pull_request_template.md`, `.github/CODEOWNERS` | Tracciabilita' nella PR e approvazioni obbligatorie |
| `.github/ISSUE_TEMPLATE/bug.yml`, `config.yml` | Modulo per le segnalazioni di bug |
| `scripts/tracciabilita.sh` | Tabella test frame -> test (anche nel riepilogo della CI) |
| `docs/fonti/` | RAD v2.9 e SDD v1.0 originali, da cui si ricavano i file di testo in `docs/` |
| `docs/modelli/class_diagram_sdd.md` | Class diagram dell'SDD in testo, con la mappatura sul database |

## 3. Lista di controllo del repository (PM)

**Repository e file**
- [x] Struttura `docs/rad/uc`, `docs/modelli`, `docs/sdd`, `docs/test` (i contenuti arrivano dai ticket dello Sprint 1)
- [x] `AGENTS.md`, `CLAUDE.md` con `@AGENTS.md`, `tester.md`, `revisore.md`
- [x] Modulo "Bug" e `blank_issues_enabled: false`
- [x] CI e template della PR su `develop` (branch predefinito)
- [ ] Settings -> Collaborators: tutti i membri con ruolo **Write**

**Permessi delle Actions**
- [x] Settings -> Actions -> General -> Workflow permissions: **Read repository contents and packages permissions** e **Allow GitHub Actions to create and approve pull requests** (serve alla release settimanale)

**Regole su `main` e `develop`** (Settings -> Rules -> Rulesets)
- [x] Require a pull request before merging, **1 approvazione**, Dismiss stale approvals, **Require review from Code Owners**
- [x] Require status checks: "Nome del branch", "Controlli DG9 e test modificati", "Formattazione, analisi e test"
- [x] Block force pushes, Restrict deletions
- [x] **Nessun bypass** per gli amministratori: anche i PM passano dall'approvazione di un'altra persona
- [ ] Aprendo `.github/CODEOWNERS` su GitHub non compaiono errori (utenti con accesso Write)

**Rilascio**
- [x] Settings -> Pages -> Source = **GitHub Actions** (sito su GitHub Pages)

## 4. Problemi tipici

| Sintomo | Causa probabile | Dove guardare |
|---|---|---|
| Check "Nome del branch" rosso | Branch non nella forma `<tipo>/KCK-<n>-...` (es. i branch `copilot/...` creati dal Copilot coding agent) | CONTRIBUTING.md, sezione 7, per rinominarlo |
| Check "Controlli DG9" rosso | SDK Supabase/FCM/Stripe importato in presentation/domain | AGENTS.md, regole DG9 |
| La CI non parte su una PR aperta da un bot o da Copilot | GitHub chiede l'approvazione prima di eseguire i workflow | Pulsante "Approve and run workflows" nella PR |
| Merge bloccato con CI verde | Manca l'approvazione, o quella del code owner | Riquadro in fondo alla PR |
| L'agente modifica file fuori dal ticket o "aggiusta" i test | Ambito non chiaro nel prompt | Ripartire dal piano; avviso della CI sui test modificati |

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
dell'SDD rispettati (controllati con il revisore); un test per ogni test frame e
CI verde; nessun test esistente modificato senza motivo scritto nella PR;
nessuna dipendenza nuova non approvata da un PM; modelli aggiornati nella stessa
PR; PR con RF/UC, artefatti ed esito del revisore; approvazione di un membro
diverso dall'autore; l'autore sa spiegare il codice.
