#!/usr/bin/env bash
# Testes do validador de exceções: casos válidos devem passar; inválidos devem falhar.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CHECK="$DIR/../../check-vuln-exceptions.sh"
TODAY="2026-11-17"
pass=0; failn=0
expect() { # $1=arquivo $2=esperado(ok|fail)
  "$CHECK" "$DIR/$1" "$TODAY" >/dev/null 2>&1; rc=$?
  want=$([[ "$2" == ok ]] && echo 0 || echo 1)
  if [[ $rc -eq $want ]]; then pass=$((pass+1)); echo "PASS $1 -> $2"; else failn=$((failn+1)); echo "FAIL $1 esperado=$2 rc=$rc"; fi
}
expect valid.yml ok
expect expired.yml fail
expect no-owner.yml fail
expect blanket.yml fail
expect bad-date.yml fail
expect typo-key.yml fail
expect empty.yml fail
expect scope-all.yml fail
echo "resumo: $pass ok, $failn falha(s)"
[[ $failn -eq 0 ]]
