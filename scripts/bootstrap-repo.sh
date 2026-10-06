#!/usr/bin/env bash
# Prepara um repositorio para o deploy: topico (entra na propagacao automatica), variables,
# secrets, environment production (revisor + so main) e aprovacao de colaboradores externos.
# Uso: bootstrap-repo.sh <owner/repo>
# Entrada por ambiente (nada e gravado em arquivo): TS_AUTHKEY e ARGOCD_TOKEN (opcionais:
# se vazios, o secret nao e alterado), ARGOCD_SERVER, K8S_API_HOST.
# DRY_RUN=1 apenas mostra o que faria.
set -euo pipefail

repo="${1:-}"
[ -n "$repo" ] || { echo "uso: bootstrap-repo.sh <owner/repo>" >&2; exit 2; }
echo "$repo" | grep -Eq '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || { echo "repositorio invalido: $repo" >&2; exit 2; }

run() { if [ "${DRY_RUN:-0}" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

run gh repo edit "$repo" --add-topic hellnet-deploy

for v in ARGOCD_SERVER K8S_API_HOST; do
  if [ -n "${!v:-}" ]; then run gh variable set "$v" --body "${!v}" -R "$repo"; fi
done

for s in TS_AUTHKEY ARGOCD_TOKEN; do
  if [ -n "${!s:-}" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then echo "[dry-run] gh secret set $s -R $repo (valor oculto)"
    else printf '%s' "${!s}" | gh secret set "$s" -R "$repo"; fi
  fi
done

uid="$(gh api user --jq .id)"
if [ "${DRY_RUN:-0}" = 1 ]; then
  echo "[dry-run] environment production em $repo (revisor id=$uid, so main)"
else
  printf '{"reviewers":[{"type":"User","id":%s}],"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}}' "$uid" |
    gh api -X PUT "repos/$repo/environments/production" --input - >/dev/null
  gh api -X POST "repos/$repo/environments/production/deployment-branch-policies" -f name=main -f type=branch >/dev/null 2>&1 || true
fi
run gh api -X PUT "repos/$repo/actions/permissions/fork-pr-contributor-approval" -f approval_policy=all_external_contributors

echo "ok: $repo preparado"
