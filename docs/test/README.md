# Category partition e test frame (docs/test)

Un file per caso d'uso: `cp_<UC>.md` (es. `cp_UC_PAR_1.md`), da copiare da
[`_TEMPLATE_cp.md`](_TEMPLATE_cp.md). Contiene parametri, categorie, scelte,
vincoli (`[error]`, `[single]`, `[property ...]`, `[if ...]`) e la tabella dei
test frame con l'esito atteso preso dal caso d'uso. I test frame sono decisi in
progettazione, NON dedotti dal codice.

## Id dei test frame

Formato unico: **`TF_<AREA>_<nn>`**, con l'area del caso d'uso (come `RF_PAR_1`,
`UC_PAR_1`) e due cifre.

- Esempio: `TF_PAR_03` e' il terzo frame dell'area partite.
- La numerazione e' progressiva per area: se `cp_UC_PAR_1.md` usa `TF_PAR_01`-`TF_PAR_12`,
  un altro caso d'uso della stessa area parte da `TF_PAR_13`. Prima di numerare:
  `grep -rho "TF_PAR_[0-9]*" docs/test | sort | tail -1`.
- Aree del RAD v2.9: `ACC` (account), `LEG` (leghe), `PAR` (partite), `PAG`
  (pagamenti), `SS` (sicurezza e condivisione), `MVP` (voto MVP), `POS` (post
  partita), `NOT` (notifiche).

## Nome dei test

Il nome del test Dart contiene l'id del frame **in minuscolo**, seguito da una
descrizione: `tf_par_03_campoGiaPrenotato_rifiuta`. Un test per ogni frame.

## Tracciabilita'

`scripts/tracciabilita.sh` legge gli id `TF_<AREA>_<nn>` dai file `cp_*.md` e
cerca un test con lo stesso id in minuscolo sotto `test/`. La tabella (frame con
e senza test) compare nel riepilogo della CI di ogni PR; in locale:
`bash scripts/tracciabilita.sh`.
