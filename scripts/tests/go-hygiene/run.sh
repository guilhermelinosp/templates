#!/usr/bin/env bash
# Testes dos passos Go de integridade do go-build.yml (Module integrity e Format).
# Extrai o run: real do workflow e roda num modulo Go temporario com git. Sem rede (GOTOOLCHAIN=local).
# Requer bash, ruby, git e go.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
WF="${HYGIENE_WF:-$DIR/../../../.github/workflows/go-build.yml}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GOTOOLCHAIN=local GOFLAGS=-mod=mod

extract() { # nome destino
  ruby -ryaml -e 'y = YAML.load_file(ARGV[0]); st = nil
    y["jobs"].each_value { |j| st ||= (j["steps"] || []).find { |s| s["name"] == ARGV[1] && s["run"] } }
    abort("passo nao encontrado: #{ARGV[1]}") unless st
    File.write(ARGV[2], st["run"])' "$WF" "$1" "$2"
}
extract "Module integrity" "$WORK/integrity.sh" || { echo "FAIL: extracao"; exit 1; }
extract "Format" "$WORK/format.sh" || { echo "FAIL: extracao"; exit 1; }

mod() { # cria modulo limpo, commitado
  rm -rf "$WORK/mod"; mkdir -p "$WORK/mod"; cd "$WORK/mod" || exit 1
  git init -q -b main
  git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false commit -q --allow-empty -m base
  go mod init example.com/hyg >/dev/null 2>&1
  printf 'package main\n\nfunc main() {}\n' > main.go
  git add -A && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m "modulo"
}

pass=0; failn=0
case_run() { # nome, esperado (ok|err), script, [pre-cmd]
  local name="$1" want="$2" script="$3"
  local out rc
  out="$(bash -eo pipefail "$script" 2>&1)"; rc=$?
  local good=0
  case "$want" in ok) [[ $rc -eq 0 ]] && good=1 ;; err) [[ $rc -ne 0 ]] && good=1 ;; esac
  if [[ $good -eq 1 ]]; then pass=$((pass + 1)); echo "PASS [$name] rc=$rc"
  else failn=$((failn + 1)); echo "FAIL [$name] esperado=$want rc=$rc"; echo "$out" | tail -4 | sed 's/^/     /'; fi
}

mod
case_run "modulo limpo: integridade passa" ok "$WORK/integrity.sh"
case_run "modulo limpo: gofmt passa" ok "$WORK/format.sh"

mod
printf 'package main\n\nfunc   main()   {}\n' > main.go && git add -A && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m "mal formatado"
out="$(bash -eo pipefail "$WORK/format.sh" 2>&1)"; rc=$?
if [[ $rc -ne 0 ]] && [[ "$out" == *main.go* ]]; then pass=$((pass + 1)); echo "PASS [gofmt reprova arquivo mal formatado e o lista] rc=$rc"
else failn=$((failn + 1)); echo "FAIL [gofmt mal formatado] rc=$rc"; echo "$out" | tail -4 | sed 's/^/     /'; fi

mod
printf 'example.com/fantasma v1.0.0 h1:AAAA=\nexample.com/fantasma v1.0.0/go.mod h1:AAAA=\n' >> go.sum && git add -A && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m "go.sum fora de sincronia"
case_run "go.sum fora de sincronia reprova (tidy muda o arquivo)" err "$WORK/integrity.sh"

echo "resumo: $pass ok, $failn falha(s)"
[[ $failn -eq 0 ]]
