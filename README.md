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

### 3. Configurazione (Supabase)

Le chiavi **non** si committano. Copia il modello e inserisci i valori che
trovi nel progetto Supabase (Settings → API):

```bash
cp config.example.json config.json
flutter run -d chrome --dart-define-from-file=config.json
```

`config.json` e' gia' in `.gitignore`.

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
  coverage e build web. Una PR rossa non si mergia.
- **Release settimanale** (`release.yml`): **ogni mercoledi'** apre in automatico
  la PR `develop → main`; un PM la approva e fa il merge (merge commit).
- **CD** (`cd.yml`): a ogni merge su `main` pubblica l'app web su GitHub Pages
  e produce un APK Android scaricabile dalla pagina del run.
- **Jira ↔ GitHub**: con l'app GitHub for Atlassian, branch, commit e PR che
  contengono la chiave del ticket (es. `KCK-60`) compaiono nel ticket Jira.

## Struttura del repository

```
lib/            codice dell'app Flutter
test/           test automatici
docs/           documentazione di progetto e di prodotto (Markdown)
.github/        CI/CD, template delle PR, CODEOWNERS
```
