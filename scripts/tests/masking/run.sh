#!/usr/bin/env bash
# Testes dos passos que antes mascaravam erro. Extrai o run: REAL dos workflows, roda com um gh falso
# (respostas por cenario) e um git real em repositorios temporarios. Confere exit code e chamadas
# de escrita (POST/DELETE). Casos de scheduled-cleanup exigem GNU date (rodam no runner Linux).
# Requer bash, ruby, jq, yq, git.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
WF="${MASKING_WF_DIR:-$DIR/../../../.github/workflows}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export WORK
CALLS="$WORK/calls"; : > "$CALLS"
export CALLS

cat > "$WORK/bin/gh" <<'MOCK'
#!/usr/bin/env bash
# falso gh: $1=api, $2=caminho; --jq aplicado com o jq real. Registra escritas em CALLS.
echo "$*" >> "$CALLS"
jqx=""; args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do [[ "${args[$i]}" == --jq ]] && jqx="${args[$((i + 1))]}"; done
emit() { if [[ -n "$jqx" ]]; then jq -r "$jqx"; else cat; fi; }
p="${2:-}"
case "$*" in *"--method POST"*|*"-X POST"*|*"-X PATCH"*) echo '{}'; exit 0 ;; esac
case "$*" in *"--method DELETE"*) echo '{}'; exit 0 ;; esac
case "$p" in
  /user)
    [[ "${GH_USER_MODE:-ok}" == fail ]] && { echo "HTTP 500: falha simulada" >&2; exit 1; }
    if [[ "${GH_USER_MODE:-ok}" == user ]]; then echo '{"type":"User"}' | emit; else echo '{"type":"Organization"}' | emit; fi ;;
  */versions*)
    case "${GH_VERS_MODE:-ok}" in
      404) echo "HTTP 404: Not Found" >&2; exit 1 ;;
      500) echo "HTTP 500: falha simulada" >&2; exit 1 ;;
      *) printf '%s' "${GH_VERS_JSON:-[]}" | emit ;;
    esac ;;
  */releases/latest) echo '{"tag_name":"v1.0.0"}' | emit ;;
  */git/ref/tags/*)
    case "${GH_TAG_MODE:-404}" in
      404) echo "HTTP 404: Not Found" >&2; exit 1 ;;
      500) echo "HTTP 500: falha simulada" >&2; exit 1 ;;
      sha:*) printf '{"object":{"sha":"%s"}}' "${GH_TAG_MODE#sha:}" | emit ;;
    esac ;;
  */commits/*) echo '{"sha":"abc123","commit":{"verification":{"verified":true}}}' | emit ;;
  */git/refs) echo '{}' ;;
  *) echo "mock gh: caminho nao previsto: $p" >&2; exit 2 ;;
esac
MOCK
chmod +x "$WORK/bin/gh"

# git real, exceto quando NT_FAIL_LOG=1: 'git log' falha (simula erro de historico)
REAL_GIT="$(command -v git)"
cat > "$WORK/bin/git.tmpl" <<'GITSHIM'
#!/usr/bin/env bash
if [[ "${NT_FAIL_LOG:-0}" == 1 && "$1" == log ]]; then echo "fatal: simulado" >&2; exit 128; fi
exec "__REAL_GIT__" "$@"
GITSHIM
sed "s#__REAL_GIT__#$REAL_GIT#" "$WORK/bin/git.tmpl" > "$WORK/bin/git" && rm -f "$WORK/bin/git.tmpl"
chmod +x "$WORK/bin/git"

# extrai o run: de um passo pelo nome (primeiro job que o contem)
extract() { # arquivo nome-do-passo destino
  ruby -ryaml -e 'y = YAML.load_file(ARGV[0]); st = nil
    y["jobs"].each_value { |j| st ||= (j["steps"] || []).find { |s| s["name"] == ARGV[1] && s["run"] } }
    abort("passo nao encontrado: #{ARGV[1]}") unless st
    File.write(ARGV[2], st["run"])' "$1" "$2" "$3"
}

pass=0; failn=0; skipn=0
# caso: nome | esperado (ok|err) | chamadas proibidas (none|no-post|no-delete|has-post|has-delete) | comando
check() {
  local name="$1" want="$2" rule="$3"; shift 3
  local out rc post del
  out="$("$@" 2>&1)"; rc=$?
  post=$(grep -c 'POST\|PATCH' "$CALLS" || true)
  del=$(grep -c 'DELETE' "$CALLS" || true)
  usersdel=$(grep -c 'DELETE.*/users/' "$CALLS" || true)
  : > "$CALLS"
  local okrc=0 okrule=1
  case "$want" in ok) [[ $rc -eq 0 ]] && okrc=1 ;; err) [[ $rc -ne 0 ]] && okrc=1 ;; esac
  case "$rule" in
    none) ;;
    no-post) [[ $post -eq 0 ]] || okrule=0 ;;
    has-post) [[ $post -gt 0 ]] || okrule=0 ;;
    no-delete) [[ $del -eq 0 ]] || okrule=0 ;;
    has-delete) [[ $del -gt 0 ]] || okrule=0 ;;
    has-delete-users) [[ $usersdel -gt 0 ]] || okrule=0 ;;
  esac
  if [[ $okrc -eq 1 && $okrule -eq 1 ]]; then
    pass=$((pass + 1)); echo "PASS [$name] rc=$rc post=$post delete=$del"
  else
    failn=$((failn + 1)); echo "FAIL [$name] esperado=$want/$rule rc=$rc post=$post delete=$del"; echo "$out" | tail -6 | sed 's/^/     /'
  fi
}
skip() { skipn=$((skipn + 1)); echo "SKIP [$1]: $2"; }

# ---------- scheduled-cleanup (GNU date) ----------
if date -d "-1 day" +%s >/dev/null 2>&1; then
  extract "$WF/scheduled-cleanup.yml" "List and delete old versions" "$WORK/cleanup.sh"
  OLD='[{"id":1,"metadata":{"container":{"tags":["v1"]}},"created_at":"2000-01-01T00:00:00Z"}]'
  NEW="[{\"id\":2,\"metadata\":{\"container\":{\"tags\":[\"v2\"]}},\"created_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}]"
  BAD='[{"id":3,"metadata":{"container":{"tags":["v3"]}},"created_at":"nao-e-data"}]'
  cl() { env PATH="$WORK/bin:$PATH" GH_TOKEN=x INPUT_PACKAGE_NAMES=app REPO_OWNER=o INPUT_DAYS_OLD=7 "$@" bash -eo pipefail "$WORK/cleanup.sh"; }
  check "cleanup: erro de API em /user" err no-delete cl GH_USER_MODE=fail INPUT_DRY_RUN=false GH_VERS_JSON="$OLD"
  check "cleanup: 404 de versoes = pacote ausente, nada a fazer" ok no-delete cl GH_VERS_MODE=404 INPUT_DRY_RUN=false
  check "cleanup: erro 500 nas versoes" err no-delete cl GH_VERS_MODE=500 INPUT_DRY_RUN=false
  check "cleanup: data invalida nao vira elegivel (timestamp 0)" err no-delete cl GH_VERS_JSON="$BAD" INPUT_DRY_RUN=false
  check "cleanup: versao antiga em dry-run nao apaga" ok no-delete cl GH_VERS_JSON="$OLD" INPUT_DRY_RUN=true
  check "cleanup: versao recente e mantida" ok no-delete cl GH_VERS_JSON="$NEW" INPUT_DRY_RUN=false
  check "cleanup: versao antiga fora de dry-run apaga (controle positivo)" ok has-delete cl GH_VERS_JSON="$OLD" INPUT_DRY_RUN=false
  check "cleanup: conta pessoal apaga pelo endpoint /users" ok has-delete-users cl GH_USER_MODE=user GH_VERS_JSON="$OLD" INPUT_DRY_RUN=false
else
  skip "scheduled-cleanup" "requer GNU date (roda no runner Linux)"
fi

# ---------- release / pipeline: tag ----------
REPO="$WORK/rel"; mkdir -p "$REPO"; (cd "$REPO" && "$REAL_GIT" init -q && "$REAL_GIT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "feat: base")
HEADSHA="$(cd "$REPO" && "$REAL_GIT" rev-parse HEAD)"
OTHER="0000000000000000000000000000000000000000"
for wf in release.yml pipeline.yml; do
  extract "$WF/$wf" "Create immutable tag through GitHub API" "$WORK/tag-$wf.sh"
  tg() { (cd "$REPO" && env PATH="$WORK/bin:$PATH" GH_TOKEN=x TAG=v1.2.3 REPOSITORY=o/r GITHUB_OUTPUT="$WORK/out" "$@" bash -eo pipefail "$WORK/tag-$wf.sh"); }
  check "$wf tag: erro 500 na leitura da tag" err no-post tg GH_TAG_MODE=500
  check "$wf tag: 404 = tag ausente, cria" ok has-post tg GH_TAG_MODE=404
  check "$wf tag: ja existe no HEAD, nao recria" ok no-post tg "GH_TAG_MODE=sha:$HEADSHA"
  check "$wf tag: existe em outro commit, falha" err no-post tg "GH_TAG_MODE=sha:$OTHER"
done

# ---------- latest: ponteiro da tag ----------
extract "$WF/latest.yml" "Point the latest tag at the latest release" "$WORK/latest.sh"
lt() { env PATH="$WORK/bin:$PATH" GH_TOKEN=x GITHUB_REPOSITORY=o/r "$@" bash -eo pipefail "$WORK/latest.sh"; }
check "latest: erro 500 ao ler a tag latest" err no-post lt GH_TAG_MODE=500
check "latest: 404 = ainda nao existe, cria" ok has-post lt GH_TAG_MODE=404

# ---------- merge-check ----------
MC="$WORK/mc"; mkdir -p "$MC"; ( cd "$MC" && "$REAL_GIT" init -q -b main && "$REAL_GIT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "chore: base" && "$REAL_GIT" init -q --bare "$WORK/origin.git" && "$REAL_GIT" remote add origin "$WORK/origin.git" && "$REAL_GIT" push -q origin main && "$REAL_GIT" checkout -q -b feat && "$REAL_GIT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "feat: ok" )
extract "$WF/merge-check.yml" "Check merge strategy (--no-ff)" "$WORK/mc1.sh"
extract "$WF/merge-check.yml" "Conventional Commits check" "$WORK/mc2.sh"
mcrun() { (cd "$MC" && env PATH="$WORK/bin:$PATH" BASE_REF=main bash -eo pipefail "$@"); }
if [[ "${HARNESS_DEBUG:-0}" == 1 ]]; then echo "DEBUG mc: $("$REAL_GIT" -C "$MC" log --oneline --all); $("$REAL_GIT" -C "$MC" remote -v | head -1)"; grep -c fetch "$WORK/mc1.sh"; fi
if [[ "${HARNESS_DEBUG:-0}" == 1 ]]; then echo "DEBUG origin branches: $("$REAL_GIT" -C "$WORK/origin.git" branch -a | tr "\n" " ")"; echo "DEBUG local refs: $("$REAL_GIT" -C "$MC" for-each-ref --format="%(refname)" | tr "\n" " ")"; fi
check "merge-check: base acessivel e commits validos passam" ok none mcrun "$WORK/mc1.sh"
( cd "$MC" && "$REAL_GIT" remote set-url origin "$WORK/nao-existe.git" )
check "merge-check: fetch da base falha = erro" err none mcrun "$WORK/mc1.sh"
( cd "$MC" && "$REAL_GIT" remote set-url origin "$WORK/origin.git" && "$REAL_GIT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m "wip: sem padrao" )
check "merge-check: commit fora do padrao reprova" err none mcrun "$WORK/mc2.sh"

# ---------- kube-resource ----------
extract "$WF/kube-resource.yml" "Check K8s resource requests/limits" "$WORK/kube.sh"
KD="$WORK/k8s"; mkdir -p "$KD"
printf '%s\n' 'apiVersion: apps/v1' 'kind: Deployment' 'metadata: {name: ok}' 'spec:' '  template:' '    spec:' '      containers:' '        - name: a' '          resources:' '            requests: {cpu: 100m, memory: 128Mi}' > "$KD/good.yaml"
printf '%s\n' 'apiVersion: apps/v1' 'kind: Deployment' 'metadata: {name: sem}' 'spec:' '  template:' '    spec:' '      containers:' '        - name: a' > "$KD/sem-requests.yaml"
printf '%s\n' 'kind: [' > "$KD/quebrado.yaml"
kr() { env PATH="$WORK/bin:$PATH" INPUT_MANIFESTS_DIR="$1" bash -eo pipefail "$WORK/kube.sh"; }
check "kube-resource: diretorio ausente falha" err none kr "$WORK/nao-existe"
mkdir -p "$WORK/k-good"; cp "$KD/good.yaml" "$WORK/k-good/"
check "kube-resource: manifesto com requests passa" ok none kr "$WORK/k-good"
mkdir -p "$WORK/k-sem"; cp "$KD/sem-requests.yaml" "$WORK/k-sem/"
check "kube-resource: sem requests reprova (controle)" err none kr "$WORK/k-sem"
mkdir -p "$WORK/k-bad"; cp "$KD/quebrado.yaml" "$WORK/k-bad/"
check "kube-resource: YAML quebrado reprova (antes passava)" err none kr "$WORK/k-bad"

echo "resumo: $pass ok, $failn falha(s), $skipn pulado(s)"
[[ $failn -eq 0 ]]
