# infrastructure

Gera `infrastructure/` plana (`application.yml` com Deployment e Service, e `kustomization.yml`) para servicos
`hellnet-service`. Dentro do repositorio do servico:

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermelinosp/templates/latest/scripts/new-infra.sh | bash -s -- <app> [--no-service] [--db] [--namespace fast] [--print-application]
```

Nao sobrescreve nada que ja exista. O chamador `infra-validate` vai para `.github/workflows/`.

## Deploy e secrets: no templates

Os repositorios dos servicos nao guardam secret nem variable. Os de deploy ficam nas configuracoes **deste** repositorio
(`templates`) e o deploy manual sai de `deploy.yml`:

```bash
gh workflow run deploy.yml -R guilhermelinosp/templates -f app=fast-platform -f action=sync
```

| Onde | O que |
|---|---|
| Secrets | `ARGOCD_TOKEN` (e `TS_AUTHKEY`, so no modo auth key) |
| Variables | `ARGOCD_SERVER`, `K8S_API_HOST` (e `TS_CLIENT_ID`, `TS_AUDIENCE` no modo OIDC) |
| Cluster (uma vez) | `appproject.yml` e `image-updater.yml` |

A config (env) de cada servico vive em `infrastructure/configmap.yml` do proprio repositorio e o ArgoCD a aplica
(so valores nao sensiveis: o repositorio e publico; senhas ficam em Secrets do cluster).
Nova app: acrescente-a em `options` e no `case` de `deploy.yml`, em `sourceRepos` do `appproject.yml` e em `image-updater.yml`.

## Versao da imagem: sempre a ultima, sem bump

A versao NAO fica no Git (`image:` sem tag). O **ArgoCD Image Updater** (`image-updater.yml`) acompanha o GHCR
e grava a ultima tag semver direto na `Application` (write-back `argocd`: sem commit e sem PR). So considera
tags que ja existem no registry, entao uma release cuja imagem ainda esta sendo construida nao e implantada.

- Instalar (uma vez): `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v1.3.0/config/install.yaml`
  e depois `kubectl apply -f infrastructure/image-updater.yml`.
- Rollback ou pausa: no `ImageUpdater`, `commonUpdateSettings.ignoreTags: "*"` (pausa) e `deploy.yml` com `tag=vX.Y.Z`.
- Merges so de `infrastructure/**` nao geram release nem imagem (`paths-ignore` no `pipeline.yml` do servico).

## Tailscale sem vencimento (identidade federada)

Auth key vence em ate 90 dias. A identidade federada nao vence e nao tem secret: o GitHub prova quem e o runner (OIDC).
Basta um passo no console, uma vez:

1. ACL (Access controls): `"tagOwners": { "tag:ci": ["autogroup:admin"] }` e um grant `{ "src": ["tag:ci"], "dst": ["192.168.1.2"], "ip": ["tcp:443"] }`.
2. Settings, Trust credentials, Credential, **OpenID Connect**: emissor GitHub, subject
   `repo:guilhermelinosp/templates:environment:production`, escopo `auth_keys` (write) com a tag `tag:ci`.
3. Cadastre as variables `TS_CLIENT_ID` e `TS_AUDIENCE` no repositorio `templates`. O `deploy.yml` passa a usar o OIDC sozinho;
   `TS_AUTHKEY` pode ser apagado.
