#!/usr/bin/env bash
# =============================================================================
# Tabella di tracciabilita' "test frame -> test" (linee guida "Agentic
# Workflow": tracciabilita' dal caso d'uso al test e metrica "test frame
# coperti"). Legge gli id TF_<AREA>_<nn> da docs/test/cp_*.md e cerca nei test
# Dart un test con lo stesso id in minuscolo (es. tf_par_03_...).
# Uso: ./scripts/tracciabilita.sh   (stampa una tabella Markdown)
# In CI l'output finisce nel riepilogo del run. Non fa fallire la build.
# =============================================================================
set -euo pipefail
shopt -s nullglob

files=(docs/test/cp_*.md)

echo "### Tracciabilita' test frame -> test"
echo
if [ ${#files[@]} -eq 0 ]; then
  echo "Nessun file docs/test/cp_*.md: ancora niente da tracciare."
  exit 0
fi

echo "| Category partition | Frame | Con test | Frame senza test |"
echo "|---|---|---|---|"
tot_all=0
cov_all=0
for f in "${files[@]}"; do
  # Id univoci dei frame dichiarati nel file.
  ids=$(grep -oE 'TF_[A-Z]+_[0-9]+' "$f" | sort -u || true)
  tot=0
  cov=0
  miss=()
  for id in $ids; do
    tot=$((tot + 1))
    low=$(echo "$id" | tr '[:upper:]' '[:lower:]')
    # Un test copre il frame se il suo nome contiene l'id in minuscolo.
    if [ -d test ] && grep -rqi --include='*.dart' -- "$low" test; then
      cov=$((cov + 1))
    else
      miss+=("$id")
    fi
  done
  tot_all=$((tot_all + tot))
  cov_all=$((cov_all + cov))
  echo "| $(basename "$f") | $tot | $cov | ${miss[*]:-nessuno} |"
done
echo
echo "Totale: $cov_all frame con test su $tot_all."
