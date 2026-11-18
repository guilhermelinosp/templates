#!/usr/bin/env bash
# Espera o alvo estar de pe antes de iniciar um scan. Aceita 2xx e 3xx, e 401/403 (alvo protegido por
# autenticacao tambem esta de pe). Respostas 4xx comuns (404 etc.) e 5xx NAO contam como prontas.
# Uso: wait-for-url.sh <url> [timeout-segundos=300]
# Variaveis:
#   CA_CERT_FILE  PEM com a CA que assina o certificado do alvo (opcional). Se definida,
#                 o arquivo precisa existir. Sem ela, valem as CAs do sistema.
# TLS e sempre validado: certificado invalido nunca conta como "pronto".
# Exit 0 quando responde; 1 se o prazo acabar; 2 se a configuracao estiver errada.
set -euo pipefail

URL="${1:?uso: wait-for-url.sh <url> [timeout]}"
TIMEOUT="${2:-300}"
CURL_ARGS=(-sS -o /dev/null -m 10 -w '%{http_code}')

if [[ -n "${CA_CERT_FILE:-}" ]]; then
  [[ -f "$CA_CERT_FILE" ]] || { echo "::error::CA_CERT_FILE nao encontrado: $CA_CERT_FILE" >&2; exit 2; }
  CURL_ARGS+=(--cacert "$CA_CERT_FILE")
fi

ERR_FILE="$(mktemp)"
trap 'rm -f "$ERR_FILE"' EXIT
DEADLINE=$(( $(date +%s) + TIMEOUT ))

while :; do
  # Falha de conexao ou de TLS e esperada enquanto o alvo sobe: curl sai com erro e imprime 000.
  # O motivo fica em ERR_FILE e so e reportado quando o prazo acaba.
  code="$(curl "${CURL_ARGS[@]}" "$URL" 2>"$ERR_FILE" || true)"
  if [[ "$code" =~ ^[0-9]+$ ]] && { (( code >= 200 && code < 400 )) || (( code == 401 || code == 403 )); }; then
    echo "pronto: $URL responde HTTP $code"
    exit 0
  fi
  if (( $(date +%s) >= DEADLINE )); then
    echo "::error::$URL nao ficou pronto em ${TIMEOUT}s (ultimo status: ${code:-sem resposta}; erro: $(tr '\n' ' ' < "$ERR_FILE"))" >&2
    exit 1
  fi
  sleep 5
done
