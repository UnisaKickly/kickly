# Kickly ⚽

[![CI](https://github.com/UnisaKickly/kickly/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/UnisaKickly/kickly/actions/workflows/ci.yml)

**Kickly** e' l'app per organizzare partite e leghe di calcio amatoriale:
registrazione, conferma presenza, pagamento della quota del campo, voto MVP e
una rete sociale tra giocatori.

Progetto del corso di **Gestione dei Progetti Software** (UNISA, a.a. 2026/27),
realizzato da zero dal team con metodologia **Scrum**.

| Ruolo | Persone |
|---|---|
| Project Manager | Mario Celzo, Renato Mancino |
| Team di sviluppo | vedi [TEAM.md](TEAM.md) |

---

## Link rapidi

| Cosa | Dove |
|---|---|
| Backlog e sprint | [Jira – progetto KCK](https://mariospaceforuni.atlassian.net/jira/software/projects/KCK/boards) |
| Come si lavora (branch, commit, PR) | [CONTRIBUTING.md](CONTRIBUTING.md) — **leggetelo prima di tutto** |
| Documentazione (RAD, SDD, ODD, PM…) | [docs/](docs/README.md) |
| App web (ultima release) | https://unisakickly.github.io/kickly/ |

## Stack

| Livello | Tecnologia | Note |
|---|---|---|
| App (Android, iOS, web) | **Flutter** (Dart) | un'unica codebase per tutte le piattaforme |
| Backend / database | **Supabase** (PostgreSQL + Auth + Storage + Edge Functions) | sicurezza con Row Level Security |
| Pagamenti | **Stripe Connect** (solo modalita' test) | commissione Kickly + quota al gestore |
| CI/CD | **GitHub Actions** | vedi `.github/workflows/` |

## Avvio rapido

### 1. Prerequisiti

- [Flutter](https://docs.flutter.dev/get-started/install) **3.47.0** (stessa
  versione della CI: controlla con `flutter --version`)
- Git e un account GitHub aggiunto all'organizzazione `UnisaKickly`
- Un editor: VS Code (estensioni *Flutter* e *Dart*) o Android Studio
- Per provare l'app: Chrome (web), un emulatore Android o il simulatore iOS (solo Mac)

### 2. Clona e avvia

```bash
git clone https://github.com/UnisaKickly/kickly.git
cd kickly
flutter pub get
flutter run -d chrome
```

### 3. Configurazione

L'app si collega al progetto Supabase del team (**kickly**, organizzazione
`UnisaKickly`, regione Central EU). URL e chiave **non** si committano: vivono
solo nel tuo `config.json` locale, che e' gia' in `.gitignore`.

1. Copia il modello:

   ```bash
   cp config.example.json config.json
   ```

2. Apri il dashboard di Supabase → progetto **kickly** → **Project Settings →
   API Keys** (o **API**) e copia in `config.json`:
   - `SUPABASE_URL`: l'URL del progetto (`https://<id-progetto>.supabase.co`);
   - `SUPABASE_ANON_KEY`: la chiave **publishable / anon** (pubblica).

   **Mai** la chiave `secret` / `service_role`: aggira le RLS e non deve
   finire ne' nell'app ne' nel repo.

3. Avvia l'app passando il file:

   ```bash
   flutter run -d chrome --dart-define-from-file=config.json
   ```

   Senza `--dart-define-from-file` l'app non si collega a Supabase e mostra
   "Configurazione mancante: avvia con --dart-define-from-file=config.json"
   (e' anche il caso della CI, che non ha `config.json`).

**Supabase CLI (opzionale, serve per migration e backend locale).** La cartella
`supabase/` contiene `config.toml`, creato con `supabase init`. Per collegare
la CLI al progetto remoto:

```bash
supabase login
supabase link --project-ref zwnmtoygwwiajffufqqc
```

Con la CLI 3.x `supabase link` di solito non chiede la password del database
(usa l'accesso del tuo `supabase login`); se la chiede, chiedila a un PM. URL,
chiavi e password si condividono solo su un canale privato (es. gestore di
password del team): mai nel repo, nei commit, nelle PR o su Jira.

### Migration sul database

Le migration (`supabase/migrations/`) si applicano **da sole** al progetto
Supabase `kickly` quando una PR che le tocca viene mergiata in `develop`
(workflow `db-deploy.yml`, vedi "CI/CD e rilasci"). Non serve fare niente a mano.

Per scrivere una migration nuova:

1. parti da `develop` aggiornato e crea il file con
   `supabase migration new <nome>`: il prefisso del nome e' la data e l'ora UTC
   di adesso, quindi e' piu' recente di tutte quelle gia' presenti. Non
   inventare il prefisso a mano;
2. prova tutto in locale (serve Docker acceso): `supabase start`,
   `supabase db reset` (applica migration e seed) e `supabase test db` (test
   pgTAP);
3. se la PR resta aperta a lungo, controlla prima del merge che nessun'altra
   migration piu' recente sia entrata in `develop`: una migration con un
   timestamp **precedente** all'ultima gia' applicata viene rifiutata e il
   deploy fallisce. In quel caso si rinomina il file con un timestamp nuovo
   (con `supabase migration new`) prima di rifare il merge. La CI lo controlla
   da sola sulle PR (passo "Controlla le regole sulle migration"): se e' rossa
   per questo motivo, l'errore dice quale file correggere.

Regole da non rompere:

- **Mai modificare una migration gia' applicata**: se serve una correzione si
  scrive una migration nuova. La CI fa fallire una PR che modifica, rinomina o
  cancella una migration gia' presente in `develop`.
- **Ogni tabella di `public` ha la RLS attiva**
  (`ALTER TABLE public.<nome> ENABLE ROW LEVEL SECURITY;` nella migration che
  la crea): il test `supabase/tests/rls_attiva_test.sql` fa fallire la CI se
  ne manca una.
- **Mai `supabase db reset` sul database remoto**: cancella tutto.
- **Mai i dati finti (`seed.sql`) sul remoto**: il seed e' solo per il database
  locale; `db push` non lo carica (non usare `--include-seed`).

Se serve applicare a mano (per esempio perche' un deploy e' caduto), con la CLI
**3.x o superiore** (`brew upgrade supabase`), da `develop` aggiornato e dopo
`supabase link`:

```bash
supabase db push --remote --dry-run   # anteprima: elenca le migration da applicare
supabase db push --remote             # le applica, chiedendo conferma
```

`--remote` e' obbligatorio: dalla CLI 3.x senza di esso il comando punta al
database locale. In alternativa, da GitHub: Actions → **Deploy database** →
Run workflow (spuntando "applica" le applica davvero).

## Comandi utili

| Comando | A cosa serve |
|---|---|
| `flutter run -d chrome` | avvia l'app nel browser |
| `dart format .` | formatta il codice (la CI lo controlla) |
| `flutter analyze` | analisi statica (la CI lo controlla) |
| `flutter test` | esegue i test |
| `flutter test --coverage` | test + report di coverage in `coverage/lcov.info` |

## Sprint

Sprint da 1–2 settimane, consegna entro i **primi di dicembre 2026**.

| Sprint | Periodo | Obiettivo |
|---|---|---|
| S0 – Setup e avvio | 12–18 ott | ambiente pronto, prima PR di tutti, documenti di avvio |
| S1 – Analisi e pianificazione | 19 ott – 1 nov | RAD e piano di progetto approvati |
| S2 – Design e fondamenta | 2–15 nov | SDD/ODD, database con RLS, login e player card |
| S3 – Leghe e partite | 16–22 nov | leghe, inviti, partite e RSVP |
| S4 – Post-partita e pagamenti | 23–29 nov | MVP, classifica, notifiche, pagamento del campo |
| S5 – Social, test e consegna | 30 nov – 6 dic | rete sociale, test report, manuali, presentazione |

## CI/CD e rilasci

- **CI** (`ci.yml`): su ogni PR verso `develop`/`main` controlla il nome del
  branch (`<tipo>/KCK-<n>-...`), formattazione, analisi statica, test con
  coverage e build web. Una PR rossa non si mergia. Sui push in `develop`/`main`
  compila anche l'app Android (debug) e, se si tocca `supabase/`, esegue i test
  del database e delle Edge Functions.
- **Release settimanale** (`release.yml`): **ogni mercoledi'** apre in automatico
  la PR `develop → main`; un PM la approva e fa il merge (merge commit).
- **CD** (`cd.yml`): a ogni merge su `main` pubblica l'app web su GitHub Pages,
  produce un APK Android (tra gli Artifacts del run) e lo allega a una GitHub
  Release. Usa i *Secrets* di repository `SUPABASE_URL` e `SUPABASE_ANON_KEY`
  (Settings → Secrets and variables → Actions → Secrets): senza, l'app
  pubblicata mostra "Configurazione mancante".
- **Deploy del database** (`db-deploy.yml`): a ogni merge in `develop` che tocca
  `supabase/migrations/**` applica le migration al progetto Supabase `kickly`
  (`supabase link` + `supabase db push --remote`, senza seed). La CI le prova
  solo su un database locale usa e getta: questo workflow e' l'unico che scrive
  sul database vero. Token e progetto stanno nell'*environment* `supabase-develop`
  (Settings → Environments, deployment branch = solo `develop`): secret
  `SUPABASE_ACCESS_TOKEN` e variable `SUPABASE_PROJECT_REF`. Si lancia anche a
  mano da Actions → "Deploy database" (di default solo anteprima). Il database
  e' uno solo (il piano gratuito di Supabase non permette un secondo progetto
  ne' il branching): lo aggiorna solo `develop`, la release su `main` non ha
  nessun passo sul DB.
- **Dependabot** (`dependabot.yml`): ogni lunedi' propone gli aggiornamenti
  delle action e delle dipendenze Dart; come ogni PR servono CI verde e
  approvazione di un PM.
- **Versione di Flutter**: e' scritta nell'azione `.github/actions/setup-flutter`
  (unico punto da cambiare per aggiornarla, insieme a questo README e ad AGENTS.md).
- **Jira ↔ GitHub**: con l'app GitHub for Atlassian, branch, commit e PR che
  contengono la chiave del ticket (es. `KCK-60`) compaiono nel ticket Jira.
  - *Come Verificare*: dopo aver fatto 'git push', apri il ticket su Jira e controlla il pannello **Sviluppo** sulla destra. 
  - *Cosa fare se non compare*: verifica che la chiave del ticket sia scritta correttamente in maiuscolo con il trattino (es. 'KCK-101', non 'kck-101' o 'KCK101').
  Se il nome del branch è errato, rinominalo seguendo [CONTRIBUTING.md]. (CONTRIBUTING.md sezione 7).

## Struttura del repository

```
lib/            codice dell'app Flutter
test/           test automatici
docs/           documentazione di progetto e di prodotto (Markdown)
.github/        CI/CD, template delle PR, CODEOWNERS
```
