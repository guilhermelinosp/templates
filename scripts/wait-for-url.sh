#!/usr/bin/env bash
# Espera uma URL responder (qualquer status HTTP < 500) antes de iniciar um scan.
# Uso: wait-for-url.sh <url> [timeout-segundos=300]
# Exit 0 quando responde; exit 1 se o prazo acabar. Nao cria infraestrutura.
set -euo pipefail

URL="${1:?uso: wait-for-url.sh <url> [timeout]}"
TIMEOUT="${2:-300}"
DEADLINE=$(( $(date +%s) + TIMEOUT ))

while :; do
  code="$(curl -sk -o /dev/null -m 10 -w '%{http_code}' "$URL" || true)"
  if [[ "$code" =~ ^[0-9]+$ ]] && (( code > 0 && code < 500 )); then
    echo "pronto: $URL responde HTTP $code"
    exit 0
  fi
  if (( $(date +%s) >= DEADLINE )); then
    echo "::error::$URL nao ficou pronto em ${TIMEOUT}s (ultimo status: ${code:-sem resposta})" >&2
    exit 1
  fi
  sleep 5
done
