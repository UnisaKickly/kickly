# Documentazione di Kickly

Tutti i documenti del progetto si scrivono qui, in Markdown, e passano da pull
request come il codice (vedi [CONTRIBUTING.md](../CONTRIBUTING.md), sezione 5).
Le PR che toccano `docs/` richiedono sempre l'approvazione dei Project Manager.

Per iniziare un nuovo documento copia [`_TEMPLATE.md`](_TEMPLATE.md).

## Dove va ogni documento

| Cartella | Documenti |
|---|---|
| `pm/` | Business case, Project Charter, Team Contract, Project Scope Statement, WBS e lista deliverable, descrizione di 2 Work Package, OBS, matrice RAM/RACI, Gantt, diagramma reticolare, budget, Risk Breakdown Structure, status report, presentazione finale, final report, lessons learned |
| `prodotto/` | RAD, SDD, ODD, Matrice di tracciabilita', interviste ai gestori |
| `test/` | Test Case Specification, Test Incident Report, Test Summary Report |
| `manuali/` | Manuale d'uso, Manuale di installazione |
| `assets/` | immagini e sorgenti dei diagrammi (draw.io, StarUML, Figma export) |

## Convenzioni

- Nome file in minuscolo con i trattini: `pm/team-contract.md`, `prodotto/rad.md`.
- Ogni documento ha l'intestazione e la revision history del template.
- I requisiti hanno ID stabili (`RF-01`, `RNF-01`), i casi d'uso pure (`UC-01`),
  i casi di test pure (`TC-01`): la matrice di tracciabilita' li collega.
- Diagrammi in Mermaid quando possibile; altrimenti immagine + sorgente in `assets/`.
