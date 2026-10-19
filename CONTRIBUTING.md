# Come si lavora su Kickly

Questa guida spiega **passo per passo** come si porta a termine un ticket Jira,
dal momento in cui lo prendi fino al merge. Vale sia per il codice sia per i
documenti (RAD, SDD, Gantt...). Se e' la prima volta che usi Git in team, leggila
tutta: ti evita il 90% dei problemi.

> Regola d'oro: **un ticket = un branch = una pull request.**
> Non si lavora mai direttamente su `main` o `develop`.

---

## 1. I branch (Git flow semplificato)

| Branch | A cosa serve | Chi ci scrive |
|---|---|---|
| `main` | versione rilasciata e funzionante (demo, consegna) | solo il merge settimanale da `develop`, **ogni mercoledi'** (vedi sezione 5) |
| `develop` | integrazione: qui confluisce il lavoro finito di tutti | solo tramite pull request approvate |
| `feature/KCK-<n>-...` | nuova funzionalita' dell'app | tu |
| `fix/KCK-<n>-...` | correzione di un bug | tu |
| `chore/KCK-<n>-...` | configurazione, CI, dipendenze, setup | tu |
| `docs/KCK-<n>-...` | documento (RAD, SDD, WBS, report...) | tu |

### La regola del nome del branch

```
<tipo>/KCK-<numero del ticket>-<quello che vuoi>
```

- **`<tipo>`** e' uno tra `feature`, `fix`, `chore`, `docs` (lo trovi anche nel
  ticket, sezione "Come consegnare").
- **`KCK-<numero>`** e' la chiave del ticket Jira che stai facendo, scritta
  esattamente cosi' (maiuscolo, con il trattino). La vedi in alto nel ticket.
- **dopo** un trattino scrivi quello che vuoi per ricordarti di cosa si
  tratta (consiglio: minuscolo, parole separate da trattini, niente spazi).

Esempi validi: `feature/KCK-60-login-email`, `fix/KCK-60-errore-password-vuota`,
`chore/KCK-24-supabase`, `docs/KCK-27-team-contract`.
Esempi **non** validi: `login` (manca tutto), `feature/login` (manca la chiave),
`feature/kck-60-login` (chiave minuscola), `Feature/KCK-60` (tipo maiuscolo),
`feature/KCK60-login` (manca il trattino nella chiave).

**Perche' e' obbligatoria.** Grazie all'app *GitHub for Atlassian* (vedi
sezione 3), la chiave nel nome del branch fa comparire in automatico branch,
commit e pull request dentro il ticket Jira, nel pannello **Sviluppo**: i PM
vedono a che punto sei senza chiedertelo e il tuo lavoro risulta tracciato.
Per questo la CI ha un controllo **"Nome del branch"**: se il nome non rispetta
la regola la PR diventa rossa e non si puo' fare il merge. Se succede, rinomina
il branch (sezione 7, "Ho sbagliato il nome del branch").

---

## 2. Il flusso completo di un ticket

### Passo 0 — Prendi il ticket su Jira

1. Nello sprint attivo scegli un ticket in **Da fare** che nessuno ha ancora
   preso. Leggi bene descrizione e criteri di accettazione.
2. Assegnatelo (**Assegna a me**) e spostalo in **In corso**.
3. Dubbi? Scrivi un commento nel ticket *prima* di iniziare, non a meta'.

### Passo 1 — Crea il branch partendo da `develop` aggiornato

```bash
git switch develop          # vai su develop
git pull                    # scarica le ultime modifiche degli altri
git switch -c feature/KCK-12-login-email   # crea il tuo branch e ci entra
```

### Passo 2 — Lavora e fai commit piccoli e frequenti

```bash
git status                  # cosa hai modificato?
git add lib/features/auth/  # aggiungi i file (evita "git add ." alla cieca)
git commit -m "feat: KCK-12 aggiunge il form di login"
```

Formato del messaggio di commit: `<tipo>: KCK-<n> <cosa fa, al presente>`

| Tipo | Quando |
|---|---|
| `feat` | nuova funzionalita' |
| `fix` | correzione di un bug |
| `docs` | documentazione |
| `test` | aggiunta o modifica di test |
| `refactor` | riorganizzazione del codice senza cambiare il comportamento |
| `chore` | configurazione, dipendenze, CI |

Un commit = una modifica logica. "fix vari" o "aggiornamenti" non sono messaggi
validi: tra un mese nessuno (nemmeno tu) capira' cosa contengono.

### Passo 3 — Prima del push: controlla in locale

```bash
dart format .
flutter analyze
flutter test
```

Sono gli stessi controlli della CI: se passano qui, passeranno anche su GitHub.
(Se il ticket e' solo documentazione puoi saltare questo passo.)

### Passo 4 — Pubblica il branch

```bash
git push -u origin feature/KCK-12-login-email   # la prima volta
git push                                         # le volte successive
```

### Passo 5 — Apri la pull request

1. Su GitHub compare il pulsante **Compare & pull request**.
2. **Base: `develop`** ← compare: il tuo branch. (Mai verso `main`.)
3. Titolo: `KCK-12: login con email e password`.
4. Compila il template (cosa cambia, come provarlo, checklist).
5. In **Reviewers** aggiungi almeno **un compagno**. Per i documenti in `docs/`
   i PM vengono aggiunti in automatico.
6. Sposta il ticket Jira in **In revisione**.

Se il lavoro non e' finito ma vuoi un parere, apri la PR come **Draft**.

### Passo 6 — Review

- Chi revisiona legge il codice/documento, lo prova e lascia commenti. Alla fine
  sceglie **Approve** oppure **Request changes**.
- Se ricevi richieste di modifica: correggi sullo **stesso branch**, fai commit e
  `git push`. La PR si aggiorna da sola. Rispondi ai commenti e segnali come
  risolti.
- Servono **1 approvazione** e la **CI verde** per fare il merge.

### Passo 7 — Merge e chiusura

1. Chi ha aperto la PR fa **Squash and merge** quando ha approvazione e CI verde.
2. Cancella il branch remoto (GitHub propone il pulsante).
3. Sposta il ticket Jira in **Fatto**.
4. In locale:

   ```bash
   git switch develop
   git pull
   git branch -d feature/KCK-12-login-email
   ```

---

## 3. Jira e GitHub collegati

### Stati dei ticket

```
Da fare  →  In corso  →  In revisione  →  Fatto
```

| Stato | Significa |
|---|---|
| **Da fare** | nessuno ci sta lavorando |
| **In corso** | assegnato a qualcuno, branch creato, lavoro in corso |
| **In revisione** | PR aperta, in attesa di review o di correzioni |
| **Fatto** | PR mergiata in `develop` e criteri di accettazione rispettati |

Un ticket fermo in **In corso** da piu' di 3 giorni va segnalato al daily scrum.

### GitHub for Atlassian (il "ponte" tra Jira e GitHub)

Sul Jira di Kickly e' installata l'app **GitHub for Atlassian** (in passato si
chiamava *GitHub for Jira*), collegata all'organizzazione GitHub `UnisaKickly`.
Cosa fa per te:

- se la **chiave del ticket** (es. `KCK-60`) compare nel **nome del branch**,
  nel **messaggio di commit** o nel **titolo della PR**, Jira la riconosce e
  mostra branch, commit, PR e stato della CI nel pannello **Sviluppo** del
  ticket;
- dal pannello **Sviluppo** del ticket puoi anche creare il branch con un clic
  ("Crea branch"): scegli `UnisaKickly/kickly`, base `develop`, e controlla che
  il nome rispetti la regola della sezione 1.

Per verificare che funzioni: dopo il primo `git push` apri il ticket su Jira e
guarda il pannello **Sviluppo** a destra (puo' servire qualche minuto). Se il
branch non compare, quasi sempre la chiave nel nome e' sbagliata.

---

## 4. Definition of Done

Un ticket e' **Fatto** solo se:

- [ ] tutti i criteri di accettazione del ticket sono rispettati;
- [ ] il lavoro e' in una PR mergiata in `develop`, con almeno 1 approvazione;
- [ ] la CI e' verde (nome del branch, formattazione, analisi, test, build);
- [ ] il codice nuovo ha i suoi test (unit o widget) e i commenti dove servono;
- [ ] i documenti toccati (RAD/SDD/ODD/matrice di tracciabilita') sono aggiornati;
- [ ] nessun segreto nel repository.

---

## 5. Rilasci: ogni mercoledi' `develop` → `main`

Durante la settimana tutto il lavoro finito confluisce in `develop` (tramite le
vostre PR). **Ogni mercoledi'** si fa il rilascio: `develop` viene unito in
`main`, e la CD pubblica la nuova versione web e l'APK Android.

Come funziona, in pratica:

1. **Mercoledi' alle 9:00** il workflow `Release settimanale` apre da solo una
   PR `develop → main` intitolata "Release settimanale – <data>", con l'elenco
   dei commit inclusi. Se `develop` non ha novita' rispetto a `main`, non apre
   nulla.
2. Un **PM** controlla la PR e la approva.
3. Il merge si fa con **"Create a merge commit"**, **mai** con "Squash and
   merge": lo squash creerebbe su `main` un commit diverso da quelli di
   `develop` e i due branch divergerebbero a ogni rilascio.
4. Dopo il merge parte la **CD**: app web su
   https://unisakickly.github.io/kickly/ e APK tra gli *Artifacts* del run.

Cosa significa per te: **entra nel rilascio del mercoledi' solo cio' che e'
mergiato in `develop` entro martedi' sera.** Se vuoi che la tua funzionalita'
sia nella demo della settimana, pianificati di conseguenza.

---

## 6. Documenti

- Tutti i documenti vivono in [`docs/`](docs/README.md), in **Markdown**, cosi'
  passano dalle PR come il codice e i PM possono revisionarli riga per riga.
- Parti sempre da [`docs/_TEMPLATE.md`](docs/_TEMPLATE.md) (intestazione e
  revision history).
- Diagrammi: [Mermaid](https://mermaid.js.org/) direttamente nel Markdown
  (GitHub li disegna da solo) oppure immagini esportate da draw.io/StarUML in
  `docs/assets/`, sempre insieme al file sorgente.
- Prima la documentazione, poi il codice: un modulo si sviluppa solo dopo che
  la sua parte di RAD e SDD e' stata approvata dai PM.
- Alla consegna i PM esportano i Markdown in PDF.

---

## 7. Problemi comuni

**"Ho sbagliato il nome del branch" (il controllo "Nome del branch" e' rosso)**

```bash
git branch -m feature/KCK-60-login-email     # rinomina il branch locale in cui sei
git push -u origin feature/KCK-60-login-email # pubblica quello col nome giusto
git push origin --delete nome-sbagliato       # cancella su GitHub quello vecchio
```

La PR aperta col nome vecchio si chiude da sola quando cancelli il branch:
aprine una nuova dal branch col nome giusto.

**"Il mio branch e' indietro rispetto a develop" / conflitti nella PR**

```bash
git switch develop && git pull
git switch feature/KCK-12-login-email
git merge develop
# risolvi i conflitti nei file segnalati (VS Code ti aiuta),
# poi: git add <file> && git commit && git push
```

**"Ho fatto commit su develop per sbaglio" (non ancora pushato)**

```bash
git switch -c feature/KCK-12-login-email   # porta i commit su un nuovo branch
git switch develop
git reset --hard origin/develop            # riporta develop com'era
```

**"Ho committato un segreto"**: avvisa subito i PM. Non basta cancellarlo con un
nuovo commit: resta nella storia, quindi va rigenerata la chiave.

**Bloccato da piu' di mezz'ora?** Chiedi. Scrivi nel ticket o nel gruppo cosa
hai provato e cosa vedi. Chiedere aiuto presto e' una cosa da professionisti.

---

## 8. Usare un assistente AI (ChatGPT, Claude, Copilot...)

E' permesso e utile, a patto di **capire tutto quello che committi**: in review
ti verra' chiesto di spiegarlo. Funziona meglio se gli dai contesto: incolla la
descrizione del ticket, il file su cui lavori e questa guida, e chiedi di
spiegarti i passi invece di darti solo il risultato.
