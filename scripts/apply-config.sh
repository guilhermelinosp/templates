#!/usr/bin/env bash
# Cria/atualiza o ConfigMap <app>-config no cluster a partir de um arquivo .env LOCAL (fora do Git).
# O Deployment gerado por new-infra.sh le esse ConfigMap (envFrom). O ArgoCD nao o rastreia.
# Uso: apply-config.sh <app> [--namespace ns] [--file caminho.env] [--restart]
# Padrao do arquivo: ~/.config/hellnet/<namespace>/<app>.env
# DRY_RUN=1 apenas mostra o ConfigMap que seria aplicado.
set -euo pipefail

app="${1:-}"
[ -n "$app" ] || { echo "uso: apply-config.sh <app> [--namespace ns] [--file caminho.env] [--restart]" >&2; exit 2; }
shift
namespace="fast" file="" restart=0
while [ $# -gt 0 ]; do
  case "$1" in
    --namespace) namespace="${2:?--namespace exige valor}"; shift ;;
    --file) file="${2:?--file exige valor}"; shift ;;
    --restart) restart=1 ;;
    *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
  esac
  shift
done

echo "$app" | grep -Eq '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$' || { echo "nome de app invalido: $app" >&2; exit 2; }
file="${file:-$HOME/.config/hellnet/${namespace}/${app}.env}"
[ -f "$file" ] || { echo "arquivo nao encontrado: $file" >&2; exit 1; }

manifest="$(kubectl -n "$namespace" create configmap "${app}-config" --from-env-file="$file" --dry-run=client -o yaml)"
if [ "${DRY_RUN:-0}" = 1 ]; then echo "$manifest"; exit 0; fi

echo "$manifest" | kubectl apply -f -
if [ "$restart" -eq 1 ]; then kubectl -n "$namespace" rollout restart "deployment/${app}"; fi
echo "ok: ${app}-config aplicado em ${namespace} (config nao e rastreada pelo ArgoCD; use --restart para recarregar)"
