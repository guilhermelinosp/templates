#!/usr/bin/env bash
# Testes do passo "Compliance" do branch-rules.yml.
# Extrai o bloco run: do YAML real, executa com um gh falso e mede o exit code direto (sem pipe).
# Requer bash, ruby (para ler o YAML), jq e base64.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
WF="${BRANCH_RULES_WF:-$DIR/../../../.github/workflows/branch-rules.yml}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ruby -ryaml -e 'y = YAML.load_file(ARGV[0]); s = y["jobs"]["validate"]["steps"].find { |x| x["name"].start_with?("Compliance") }; File.write(ARGV[1], s["run"])' "$WF" "$WORK/step.sh" || { echo "FAIL: nao extraiu o run"; exit 1; }

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'MOCK'
#!/usr/bin/env bash
# Falso gh: TREE_MODE, CI_RESP e REL_RESP escolhem o cenario. --jq e aplicado com o jq real.
jqexpr=""; args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do [[ "${args[$i]}" == --jq ]] && jqexpr="${args[$((i + 1))]}"; done
emit() { if [[ -n "$jqexpr" ]]; then jq -r "$jqexpr"; else cat; fi; }
pin_b64()  { printf 'uses: guilhermelinosp/templates/.github/workflows/x.yml@%s\n' "$(printf 'a%.0s' $(seq 40))" | base64 | tr -d '\n'; }
main_b64() { printf 'uses: guilhermelinosp/templates/.github/workflows/x.yml@main\n' | base64 | tr -d '\n'; }
case "$*" in
  *"git/trees"*)
    case "${TREE_MODE:-ok}" in
      ok)        printf '%s' '{"truncated":false,"tree":[{"path":".github/workflows/ci.yml"},{"path":".github/workflows/rel.yml"},{"path":"README.md"}]}' | emit ;;
      none)      printf '%s' '{"truncated":false,"tree":[{"path":"README.md"}]}' | emit ;;
      http)      echo '{"message":"Server Error"}' >&2; exit 1 ;;
      badjson)   printf '%s' '{"truncated":false,"tree":[' | emit ;;
      truncated) printf '%s' '{"truncated":true,"tree":[{"path":"README.md"}]}' | emit ;;
      nofield)   printf '%s' '{"sha":"x"}' | emit ;;
    esac ;;
  *"contents/"*)
    case "$*" in
      *rel.yml*) resp="${REL_RESP:-pin}" ;;
      *)         resp="${CI_RESP:-pin}" ;;
    esac
    case "$resp" in
      pin)      printf '{"content":"%s"}' "$(pin_b64)" | emit ;;
      main)     printf '{"content":"%s"}' "$(main_b64)" | emit ;;
      empty)    printf '%s' '{"content":""}' | emit ;;
      http)     echo '{"message":"Not Found"}' >&2; exit 1 ;;
      badjson)  printf '%s' '{"content":' | emit ;;
      nocontent) printf '%s' '{"name":"x"}' | emit ;;
      badb64)   printf '%s' '{"content":"!!!###"}' | emit ;;
    esac ;;
  *) echo "mock: chamada nao prevista: $*" >&2; exit 2 ;;
esac
MOCK
chmod +x "$WORK/bin/gh"

pass=0; failn=0
# nome | rc esperado | TREE_MODE | CI_RESP | REL_RESP
run_case() {
  local name="$1" want="$2" tree="$3" ci="$4" rel="$5"
  local out rc
  out="$(cd "$WORK" && env PATH="$WORK/bin:$PATH" REPO_FULL=o/r COMMIT_SHA="$(printf 'a%.0s' $(seq 40))" TREE_MODE="$tree" CI_RESP="$ci" REL_RESP="$rel" bash -eo pipefail "$WORK/step.sh" 2>&1)"
  rc=$?
  # ok   : rc 0 e mensagem de sucesso
  # viol : rc != 0 e a violacao foi reportada
  # err  : rc != 0 e nenhuma mensagem de sucesso (erro de API/JSON/arvore)
  local ok=0
  case "$want" in
    ok)   [[ $rc -eq 0 && "$out" == *"OK"* ]] && ok=1 ;;
    viol) [[ $rc -ne 0 && "$out" == *"não imutável"* ]] && ok=1 ;;
    err)  [[ $rc -ne 0 && "$out" != *"OK"* && "$out" != *"não imutável"* ]] && ok=1 ;;
  esac
  if [[ $ok -eq 1 ]]; then
    pass=$((pass + 1)); echo "PASS [$name] rc=$rc"
  else
    failn=$((failn + 1)); echo "FAIL [$name] esperado=$want, obtido rc=$rc"; echo "$out" | tail -2 | sed 's/^/     /'
  fi
}

# sucesso sem violacao: a unica situacao que deve dar 0 alem de "nao ha workflows"
run_case "consulta ok, pins SHA"                    ok ok   pin   pin
run_case "consulta ok, sem workflows"               ok none pin   pin
run_case "arquivo vazio (sucesso sem conteudo)"     ok ok   empty pin
# violacao real
run_case "violacao em ci.yml (@main)"               viol ok   main  pin
run_case "violacao so em rel.yml (@main)"           viol ok   pin   main
# erro da API na arvore
run_case "arvore: erro HTTP"                        err http   pin pin
run_case "arvore: JSON invalido"                    err badjson pin pin
run_case "arvore: truncada pela API"                err truncated pin pin
run_case "arvore: campo tree ausente"               err nofield pin pin
# erro da API no conteudo
run_case "conteudo ci.yml: erro HTTP"               err ok http pin
run_case "conteudo ci.yml: JSON invalido"           err ok badjson pin
run_case "conteudo ci.yml: sem campo content"       err ok nocontent pin
run_case "conteudo ci.yml: base64 invalido"         err ok badb64 pin
run_case "conteudo rel.yml: erro HTTP (ci ok)"      err ok pin http
run_case "conteudo rel.yml: JSON invalido (ci ok)"  err ok pin badjson

echo "resumo: $pass ok, $failn falha(s)"
[[ $failn -eq 0 ]]
