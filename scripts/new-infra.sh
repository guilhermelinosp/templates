#!/usr/bin/env bash
# Gera infra/ (Kustomize + Application do ArgoCD) e os workflows chamadores no repositorio atual.
# Uso: new-infra.sh <app> [--no-service] [--db] [--tag vX.Y.Z] [--namespace ns] [--owner org]
# Variaveis: TEMPLATES_REF (default latest), TEMPLATES_DIR (usa um checkout local em vez de baixar)
set -euo pipefail

app="${1:-}"
[ -n "$app" ] || { echo "uso: new-infra.sh <app> [--no-service] [--db] [--tag vX.Y.Z] [--namespace ns] [--owner org]" >&2; exit 2; }
shift

service=1 db=0 tag="v0.0.0" namespace="fast" owner="guilhermelinosp"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-service) service=0 ;;
    --db) db=1 ;;
    --tag) tag="${2:?--tag exige valor}"; shift ;;
    --namespace) namespace="${2:?--namespace exige valor}"; shift ;;
    --owner) owner="${2:?--owner exige valor}"; shift ;;
    *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

echo "$app" | grep -Eq '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' || { echo "nome de app invalido: $app" >&2; exit 2; }
echo "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$' || { echo "tag invalida: $tag" >&2; exit 2; }
[ ! -e infra ] || { echo "infra/ ja existe; nada foi alterado" >&2; exit 1; }

ref="${TEMPLATES_REF:-latest}"
image="ghcr.io/${owner}/${app}"

fetch() { # <caminho relativo a infra-template>
  if [ -n "${TEMPLATES_DIR:-}" ]; then cat "${TEMPLATES_DIR}/infra-template/$1"
  else curl -fsSL "https://raw.githubusercontent.com/guilhermelinosp/templates/${ref}/infra-template/$1"; fi
}

render() { # <origem> <destino>
  mkdir -p "$(dirname "$2")"
  fetch "$1" | awk -v svc="$service" -v db="$db" '
    /^#SVC-BEGIN$/ { skip = (svc == 0); inblk = 1; next }
    /^#SVC-END$/   { skip = 0; inblk = 0; next }
    /^#DB-BEGIN$/  { skip = (db == 0); inblk = 1; next }
    /^#DB-END$/    { skip = 0; inblk = 0; next }
    !skip { print }' |
    sed -e "s#__APP__#${app}#g" -e "s#__IMAGE__#${image}#g" -e "s#__TAG__#${tag}#g" \
        -e "s#__NAMESPACE__#${namespace}#g" -e "s#__OWNER__#${owner}#g" > "$2"
}

render base/deployment.yaml infra/base/deployment.yaml
[ "$service" -eq 1 ] && render base/service.yaml infra/base/service.yaml
render base/kustomization.yaml infra/base/kustomization.yaml
render base/config.env infra/base/config.env
render overlays/homelab/kustomization.yaml infra/overlays/homelab/kustomization.yaml
render argocd/application.yaml infra/argocd/application.yaml

for wf in argocd infra-validate; do
  [ ! -e ".github/workflows/${wf}.yml" ] || { echo ".github/workflows/${wf}.yml ja existe; mantido" >&2; continue; }
  render "caller/${wf}.yml" ".github/workflows/${wf}.yml"
done

echo "ok: infra/ criado para ${app} (namespace ${namespace}, tag ${tag})"
echo "valide: kubectl kustomize infra/overlays/homelab"
