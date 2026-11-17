<!--
  Modello per la category partition di un caso d'uso.
  1. Copia questo file in docs/test/cp_<UC>.md o cp_<UC>_<UC>.md, come dice il ticket
     (es. cp_UC_PAR_1_UC_PAG_1.md).
  2. Sostituisci i campi tra <...> e cancella le righe di esempio.
  3. Gli id dei frame seguono le regole di docs/test/README.md (TF_<AREA>_<nn>).
  Questo file non viene letto da scripts/tracciabilita.sh (non inizia con cp_).
-->

# Category partition - <UC_AREA_n> <Nome del caso d'uso>

| | |
|---|---|
| **Caso d'uso** | `docs/rad/uc/<UC_AREA_n_Nome>.md` |
| **Requisiti** | <RF_AREA_n, ...> |
| **Metodo testato** | <Classe Control e metodo, dal class diagram (es. `PartitaControl.creaPartita`)> |
| **Autori** | <Nome Cognome> |
| **Revisori** | <Nome Cognome> |

## 1. Parametri e condizioni dell'ambiente

Gli input del metodo e lo stato del sistema che ne cambia il comportamento.

| Parametro / condizione | Descrizione |
|---|---|
| <parametro 1> | <es. data e ora della partita> |
| <condizione 1> | <es. stato della prenotazione del campo> |

## 2. Categorie e scelte

Per ogni parametro: le categorie e, per ciascuna, le scelte. I vincoli:
- `[error]` scelta che da sola porta a un errore: un solo frame, non si combina;
- `[single]` scelta da provare una sola volta;
- `[property X]` assegna la proprieta' X; `[if X]` scelta valida solo se c'e' X.

### <Parametro 1>

| Categoria | Scelta | Vincolo |
|---|---|---|
| <categoria> | <scelta valida> | `[property <X>]` |
| <categoria> | <scelta non valida> | `[error]` |

### <Condizione 1>

| Categoria | Scelta | Vincolo |
|---|---|---|
| <categoria> | <scelta> | `[if <X>]` |
| <categoria> | <scelta limite> | `[single]` |

## 3. Test frame

L'esito atteso si prende dal caso d'uso (flusso principale, alternativo o di
errore), mai dal comportamento del codice. Ogni frame avra' un test con l'id in
minuscolo nel nome (es. `tf_<area>_01_...`).

| Id | Scelte combinate | Preparazione | Esito atteso | Flusso del caso d'uso |
|---|---|---|---|---|
| TF_<AREA>_01 | <scelta 1, scelta 2> | <stato iniziale> | <risultato e stato dopo l'operazione> | <flusso principale, passo n> |
| TF_<AREA>_02 | <scelta non valida> | <stato iniziale> | <messaggio di errore previsto> | <flusso di errore n> |

Totale frame: <n>
