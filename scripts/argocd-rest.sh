#!/usr/bin/env bash
# Opera uma Application do ArgoCD pela API REST (o Gateway nao passa gRPC-web, entao o argocd CLI nao serve).
# Env: ARGOCD_SERVER, ARGOCD_AUTH_TOKEN, APP, ACTION (diff|sync), TAG (opcional), IMAGE_BASE, NAMESPACE, RESTART (true|false)
set -euo pipefail

: "${ARGOCD_SERVER:?}" "${ARGOCD_AUTH_TOKEN:?}" "${APP:?}" "${ACTION:?}" "${IMAGE_BASE:?}" "${NAMESPACE:?}"
TAG="${TAG:-}" RESTART="${RESTART:-false}" TIMEOUT="${TIMEOUT:-300}"
base="${ARGOCD_SCHEME:-https}://${ARGOCD_SERVER}/api/v1/applications/${APP}"
image="${IMAGE_BASE}/${APP}"

api() { curl -sS --fail-with-body --max-time 30 -H "Authorization: Bearer ${ARGOCD_AUTH_TOKEN}" -H 'Content-Type: application/json' "$@"; }

live_image() {
  api "${base}/resource?namespace=${NAMESPACE}&resourceName=${APP}&version=v1&group=apps&kind=Deployment" |
    jq -r '.manifest | fromjson | .spec.template.spec.containers[0].image'
}
rollout_ok() {
  api "${base}/resource?namespace=${NAMESPACE}&resourceName=${APP}&version=v1&group=apps&kind=Deployment" |
    jq -e '.manifest | fromjson | (.status.updatedReplicas // 0) == .spec.replicas and (.status.availableReplicas // 0) == .spec.replicas and ((.status.replicas // 0) == .spec.replicas)' >/dev/null
}

if [ -n "$TAG" ]; then
  patch="$(jq -nc --arg i "${image}:${TAG}" '{spec:{source:{kustomize:{images:[$i]}}}}')"
  body="$(jq -nc --arg n "$APP" --arg p "$patch" '{name:$n,patch:$p,patchType:"merge"}')"
  api -X PATCH -d "$body" "$base" >/dev/null
  echo "imagem definida na Application: ${image}:${TAG}"
fi

case "$ACTION" in
  diff)
    api "$base" | jq '{app:.metadata.name, sync:.status.sync.status, health:.status.health.status,
      imagens:.spec.source.kustomize.images, fora_de_sync:[.status.resources[]?|select(.status!="Synced")|"\(.kind)/\(.name)"]}'
    echo "imagem no Deployment: $(live_image)"
    ;;
  sync)
    # com sync automatico o ArgoCD ja reage ao patch; o POST e idempotente (tolera "operacao em andamento")
    api -X POST -d '{}' "${base}/sync" >/dev/null || echo "sync: ja em andamento"
    deadline=$((SECONDS + TIMEOUT))
    while :; do
      app="$(api "$base")"
      phase="$(jq -r '.status.operationState.phase // "-"' <<<"$app")"
      sync="$(jq -r '.status.sync.status' <<<"$app")"
      health="$(jq -r '.status.health.status' <<<"$app")"
      cur="$(live_image 2>/dev/null || echo '?')"
      echo "fase=${phase} sync=${sync} saude=${health} imagem=${cur##*/}"
      if [ "$phase" != Running ] && [ "$sync" = Synced ] && [ "$health" = Healthy ] \
         && { [ -z "$TAG" ] || [ "$cur" = "${image}:${TAG}" ]; } && rollout_ok; then
        echo "implantado: ${cur}"; break
      fi
      [ "$phase" = Failed ] || [ "$phase" = Error ] && { echo "::error::sync falhou: $(jq -r '.status.operationState.message' <<<"$app")"; exit 1; }
      [ "$SECONDS" -lt "$deadline" ] || { echo "::error::timeout (${TIMEOUT}s) esperando a implantacao"; exit 1; }
      sleep 5
    done
    ;;
  *) echo "::error::acao invalida: $ACTION"; exit 2 ;;
esac

if [ "$RESTART" = true ]; then
  api -X POST -d '"restart"' "${base}/resource/actions?namespace=${NAMESPACE}&resourceName=${APP}&version=v1&group=apps&kind=Deployment" >/dev/null
  echo "restart solicitado"
fi
