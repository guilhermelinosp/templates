#!/usr/bin/env bash
# Valida o arquivo de exceções de vulnerabilidade.
# Uso: check-vuln-exceptions.sh [arquivo] [data-de-referencia AAAA-MM-DD]
# Falha (exit 1) se: campo obrigatório ausente, id fora do padrão, escopo vazio/genérico,
# data inválida ou expirada. Sem dependências além de yq (mikefarah) e date.
set -euo pipefail

FILE="${1:-security/vuln-exceptions.yml}"
TODAY="${2:-$(date -u +%Y-%m-%d)}"
ERRORS=0

# Data real? date normaliza 2027-02-30 em alguns sistemas; a ida e volta exige igualdade.
valid_date() {
  local d="$1" back
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
  if back="$(date -j -f %Y-%m-%d "$d" +%Y-%m-%d 2>/dev/null)"; then :; \
  elif back="$(date -d "$d" +%Y-%m-%d 2>/dev/null)"; then :; \
  else return 1; fi
  [[ "$back" == "$d" ]]
}


fail() { echo "::error file=${FILE}::$1" >&2; ERRORS=$((ERRORS + 1)); }

[[ -f "$FILE" ]] || { echo "arquivo nao encontrado: $FILE" >&2; exit 1; }
command -v yq >/dev/null || { echo "yq ausente" >&2; exit 1; }

KIND="$(yq '.exceptions | tag' "$FILE")"
[[ "$KIND" == "!!seq" ]] || { echo "chave 'exceptions' ausente ou nao e uma lista em $FILE" >&2; exit 1; }
COUNT="$(yq '.exceptions | length' "$FILE")"
for ((i = 0; i < COUNT; i++)); do
  id="$(yq ".exceptions[$i].id // \"\"" "$FILE")"
  scope="$(yq ".exceptions[$i].scope // \"\"" "$FILE")"
  reason="$(yq ".exceptions[$i].reason // \"\"" "$FILE")"
  owner="$(yq ".exceptions[$i].owner // \"\"" "$FILE")"
  expires="$(yq ".exceptions[$i].expires // \"\"" "$FILE")"
  n=$((i + 1))

  [[ "$id" =~ ^(CVE-[0-9]{4}-[0-9]+|GHSA-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}|OSV-[A-Za-z0-9.-]+)$ ]] \
    || fail "exceção $n: id inválido ou genérico ('$id'); use CVE-, GHSA- ou OSV- específico"
  case "$scope" in
    ''|'*'|'**'|'.'|'all') fail "exceção $n ($id): escopo ausente ou genérico ('$scope'); informe pacote, imagem ou arquivo" ;;
  esac
  [[ ${#reason} -ge 10 ]] || fail "exceção $n ($id): motivo ausente ou curto demais"
  [[ "$owner" =~ ^@[A-Za-z0-9-]+$ ]] || fail "exceção $n ($id): owner deve ser um @handle"
  if ! valid_date "$expires"; then
    fail "exceção $n ($id): data de expiração inválida ('$expires')"
  elif [[ "$expires" < "$TODAY" ]]; then
    fail "exceção $n ($id): expirada em $expires (hoje $TODAY)"
  fi
done

if (( ERRORS > 0 )); then
  echo "FAIL: $ERRORS problema(s) em $FILE" >&2
  exit 1
fi
echo "OK: $COUNT exceção(ões) válida(s) em $FILE"
