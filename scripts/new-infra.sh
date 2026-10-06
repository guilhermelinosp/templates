#!/usr/bin/env bash
# Gera infrastructure/ plana: application.yml (Deployment + Service), configmap.yml e kustomization.yml.
# A config (env) e os secrets ficam so no repositorio templates (deploy.yml). A Application do ArgoCD sai com --print-application.
# Tambem cria o chamador infra-validate em .github/workflows/.
# Uso: new-infra.sh <app> [--no-service] [--db] [--namespace ns] [--owner org] [--project nome] [--print-application]
# Variaveis: TEMPLATES_REF (default latest), TEMPLATES_DIR (usa um checkout local em vez de baixar)
set -euo pipefail

app="${1:-}"
[ -n "$app" ] || { echo "uso: new-infra.sh <app> [--no-service] [--db] [--namespace ns] [--owner org] [--project nome] [--print-application]" >&2; exit 2; }
shift

print_app=0 service=1 db=0 namespace="fast" owner="guilhermelinosp" project="fast"
while [ $# -gt 0 ]; do
  case "$1" in
    --no-service) service=0 ;;
    --print-application) print_app=1 ;;
    --db) db=1 ;;
    --namespace) namespace="${2:?--namespace exige valor}"; shift ;;
    --owner) owner="${2:?--owner exige valor}"; shift ;;
    --project) project="${2:?--project exige valor}"; shift ;;
    *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

echo "$app" | grep -Eq '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' || { echo "nome de app invalido: $app" >&2; exit 2; }
[ ! -e infrastructure ] || { echo "infrastructure/ ja existe; nada foi alterado" >&2; exit 1; }

ref="${TEMPLATES_REF:-latest}"
image="ghcr.io/${owner}/${app}"

fetch() { # <caminho relativo a infrastructure>
  if [ -n "${TEMPLATES_DIR:-}" ]; then cat "${TEMPLATES_DIR}/infrastructure/$1"
  else curl -fsSL "https://raw.githubusercontent.com/guilhermelinosp/templates/${ref}/infrastructure/$1"; fi
}

render() { # <origem> <destino>
  mkdir -p "$(dirname "$2")"
  fetch "$1" | awk -v svc="$service" -v db="$db" '
    /^#SVC-BEGIN$/ { skip = (svc == 0); inblk = 1; next }
    /^#SVC-END$/   { skip = 0; inblk = 0; next }
    /^#DB-BEGIN$/  { skip = (db == 0); inblk = 1; next }
    /^#DB-END$/    { skip = 0; inblk = 0; next }
    !skip { print }' |
    sed -e "s#__APP__#${app}#g" -e "s#__IMAGE__#${image}#g" \
        -e "s#__NAMESPACE__#${namespace}#g" -e "s#__OWNER__#${owner}#g" -e "s#__PROJECT__#${project}#g" > "$2"
}

render application.yml infrastructure/application.yml
render configmap.yml infrastructure/configmap.yml
render kustomization.yml infrastructure/kustomization.yml

if [ -e .github/workflows/infra-validate.yml ]; then echo ".github/workflows/infra-validate.yml ja existe; mantido" >&2
else render caller/infra-validate.yml .github/workflows/infra-validate.yml; fi

echo "ok: infrastructure/ criado para ${app} (namespace ${namespace})"
echo "valide: kubectl kustomize infrastructure"
echo "config: edite infrastructure/configmap.yml (so valores nao sensiveis: o repositorio e publico)"
if [ "$print_app" -eq 1 ]; then
  echo "--- Application do ArgoCD (kubectl apply -f -)"
  fetch argocd-application.yml | sed -e "s#__APP__#${app}#g" -e "s#__NAMESPACE__#${namespace}#g" -e "s#__OWNER__#${owner}#g" -e "s#__PROJECT__#${project}#g"
fi
