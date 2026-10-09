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
| `main` | versione rilasciata e funzionante (demo, consegna) | solo merge da `develop` a fine sprint, fatto dai PM |
| `develop` | integrazione: qui confluisce il lavoro finito di tutti | solo tramite pull request approvate |
| `feature/KCK-<n>-<descrizione>` | nuova funzionalita' dell'app | tu |
| `docs/KCK-<n>-<descrizione>` | documento (RAD, SDD, WBS, report...) | tu |
| `fix/KCK-<n>-<descrizione>` | correzione di un bug | tu |
| `chore/KCK-<n>-<descrizione>` | configurazione, CI, dipendenze | tu |

`KCK-<n>` e' la chiave del ticket Jira (la vedi in alto nel ticket, es.
`KCK-12`). La descrizione e' breve, minuscola, con i trattini:
`feature/KCK-12-login-email`, `docs/KCK-5-team-contract`.

Mettere la chiave nel nome del branch serve: Jira collega in automatico branch,
commit e PR al ticket, e i PM vedono a che punto sei senza chiedertelo.

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

## 3. Stati dei ticket su Jira

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

---

## 4. Definition of Done

Un ticket e' **Fatto** solo se:

- [ ] tutti i criteri di accettazione del ticket sono rispettati;
- [ ] il lavoro e' in una PR mergiata in `develop`, con almeno 1 approvazione;
- [ ] la CI e' verde (formattazione, analisi, test, build);
- [ ] il codice nuovo ha i suoi test (unit o widget) e i commenti dove servono;
- [ ] i documenti toccati (RAD/SDD/ODD/matrice di tracciabilita') sono aggiornati;
- [ ] nessun segreto nel repository.

---

## 5. Documenti

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

## 6. Problemi comuni

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

## 7. Usare un assistente AI (ChatGPT, Claude, Copilot...)

E' permesso e utile, a patto di **capire tutto quello che committi**: in review
ti verra' chiesto di spiegarlo. Funziona meglio se gli dai contesto: incolla la
descrizione del ticket, il file su cui lavori e questa guida, e chiedi di
spiegarti i passi invece di darti solo il risultato.
