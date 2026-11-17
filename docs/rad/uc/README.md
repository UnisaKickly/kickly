# Casi d'uso (docs/rad/uc)

Un file Markdown per caso d'uso, ricavato dal RAD v2.9 (sezione 3.4.2), con
questo nome: `UC_<AREA>_<n>_<Nome>.md` (es. `UC_PAR_1_CreazionePartita.md`).
Ogni file riporta: identificativo, attori, entry/exit condition, flusso principale,
flussi di errore e alternativi, RF collegati. Gli agenti leggono SOLO questi file
(non tutto il RAD): se un'eccezione e' vaga, il codice generato sara' vago.
