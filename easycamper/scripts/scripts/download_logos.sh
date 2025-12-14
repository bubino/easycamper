#!/usr/bin/env bash
set -euo pipefail

# Controlla che jq sia installato
command -v jq >/dev/null 2>&1 || { 
  echo >&2 "❗️ jq non trovato, installalo con: brew install jq"; 
  exit 1; 
}

# Crea cartella per i loghi
mkdir -p assets/logos/brands

# leggi dominio e brand separati da tab, così i brand con spazi non vengono spezzati
jq -r 'to_entries[] | "\(.value.domain)\t\(.key)"' assets/data/brands.json |
while IFS=$'\t' read -r domain brand; do
  # genera filename pulito
  filename=$(echo "$brand" \
    | tr '[:upper:] ' '[:lower:]_' \
    | tr -cd '[:alnum:]_').png

  target="assets/logos/brands/$filename"
  echo "↓ $brand ($domain) → $target"

  if curl -sSf "https://logo.clearbit.com/$domain" -o "$target"; then
    echo "   → OK"
  else
    echo "   → ⚠️ Clearbit ha restituito errore per $brand"
    echo "     Scarica manualmente e metti in $target"
  fi
done
