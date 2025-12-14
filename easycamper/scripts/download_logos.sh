#!/usr/bin/env bash
set -euo pipefail

# 1) Calcola la root del progetto (uno sopra scripts/)
PROJECT_ROOT="$(cd "$(dirname "$0")"/.. && pwd)"
BRANDS_JSON="$PROJECT_ROOT/assets/data/brands.json"
LOGO_DIR="$PROJECT_ROOT/assets/logos/brands"

# 2) Controlla che jq sia installato
if ! command -v jq >/dev/null 2>&1; then
  echo "❗️ jq non trovato. Installa con: brew install jq"
  exit 1
fi

# 3) Crea la cartella dei loghi
mkdir -p "$LOGO_DIR"

# 4) Per ciascun brand scarica da Clearbit, altrimenti usa il fallback hard-coded
jq -r 'to_entries[] | "\(.key)\t\(.value.domain)"' "$BRANDS_JSON" | \
while IFS=$'\t' read -r brand domain; do
  # genera un filename pulito
  filename="$(echo "$brand" \
    | tr '[:upper:] ' '[:lower:]_' \
    | tr -cd '[:alnum:]_').png"
  target="$LOGO_DIR/$filename"

  echo "↓ $brand ($domain) → $filename"

  # 4a) Prova Clearbit
  if curl -sSf "https://logo.clearbit.com/$domain" -o "$target"; then
    echo "   → OK (Clearbit)"
    continue
  fi

  echo "   → ⚠️ Clearbit ha restituito errore, provo fallback…"

  # 4b) fallback manuali per i casi problematici
  fb=""
  case "$brand" in
    "Benimar")       fb="benimar.es" ;;
    "Chausson")      fb="chausson-camping-cars.fr" ;;
    "Euramobil")     fb="euramobil.de" ;;
    "Mobilvetta")    fb="mobilvetta.it" ;;
    "Rapido")        fb="rapido.fr" ;;
    "Karmann Mobil") fb="" ;;  # nessun logo noto
    *)               fb="" ;;
  esac

  if [ -n "$fb" ]; then
    if curl -sSf "https://logo.clearbit.com/$fb" -o "$target"; then
      echo "   → OK (fallback: $fb)"
    else
      echo "   → ❌ Fallback $fb fallito"
    fi
  else
    echo "   → ⚠️ Nessun fallback configurato per $brand"
  fi
done
