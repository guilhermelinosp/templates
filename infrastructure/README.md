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

## Tailscale sem vencimento (identidade federada, OIDC)

Auth key vence em ate 90 dias. A identidade federada nao vence e nao tem secret: o GitHub prova quem e o runner (OIDC).
O `deploy.yml` e o `tailscale-check.yml` usam o OIDC sozinhos quando as variables `TS_CLIENT_ID` e `TS_AUDIENCE` existem
(os dois jobs rodam no environment `production`, entao compartilham o mesmo subject). Passos no console, uma vez:

1. **ACL** (Access controls), acrescente:
   ```json
   "tagOwners": { "tag:ci": ["autogroup:admin"] },
   "grants": [ { "src": ["tag:ci"], "dst": ["192.168.1.2"], "ip": ["tcp:443"] } ]
   ```
2. **Settings, Trust credentials, Credential, OpenID Connect**:
   - Issuer: GitHub (`https://token.actions.githubusercontent.com`)
   - Subject: `repo:guilhermelinosp/templates:environment:production`
   - Escopo `auth_keys` (write), tag `tag:ci`.
3. Copie o **Client ID** e o **Audience** gerados e cadastre-os como **variables** (nao secrets) no `templates`:
   `gh variable set TS_CLIENT_ID --body <id> -R guilhermelinosp/templates` e `gh variable set TS_AUDIENCE --body <audience> -R guilhermelinosp/templates`.
4. Rode o `tailscale-check` (workflow_dispatch). Se passar no modo "identidade federada", apague o secret `TS_AUTHKEY`.

## CD nos Actions de cada servico

O `pipeline.yml` do servico tem um job `cd` depois de `release` e `image`:

```yaml
  cd:
    name: cd
    needs: [release, image]
    uses: guilhermelinosp/templates/.github/workflows/cd.yml@latest
    with:
      app: fast-platform
      version: ${{ needs.release.outputs.version }}
      app-client-id: ${{ vars.HELLNET_ACTIONS_CLIENT_ID }}
    secrets: inherit
```

Ele dispara o `deploy.yml` deste repositorio (hub, com `action=sync` e a `tag` publicada) e espera: o resultado, com o link do
run no hub, aparece e falha no Actions do proprio servico. Os secrets do Tailscale e do ArgoCD continuam so aqui; o servico usa o
GitHub App que ja tem. **Pre-requisito unico:** o App `hellnet-actions` precisa da permissao **Actions: Read and write** e estar
instalado neste repositorio. O deploy.yml fala com o ArgoCD pela **API REST** (`scripts/argocd-rest.sh`), porque o Gateway nao passa gRPC-web.

## Aviso de vencimento da auth key

O workflow `tailscale-check` roda toda segunda: tenta entrar no tailnet e alcancar o ArgoCD. Se falhar (em geral porque a auth key
venceu), abre uma issue. Defina a variable `TS_AUTHKEY_EXPIRES` (AAAA-MM-DD) para um aviso 14 dias antes. A identidade federada
(secao acima) elimina a renovacao.

## Modos de autenticacao no Tailscale (ordem de preferencia)

O `deploy.yml` e o `tailscale-check.yml` escolhem sozinhos, pelas variables e secrets existentes:

| Modo | Condicao | Vence? | Secret |
|---|---|---|---|
| Identidade federada (OIDC) | variables `TS_CLIENT_ID` e `TS_AUDIENCE` | nao | nao |
| OAuth client | variable `TS_CLIENT_ID` e secret `TS_OAUTH_SECRET` (sem `TS_AUDIENCE`) | nao | sim |
| Auth key | nenhuma das anteriores | em ate 90 dias | `TS_AUTHKEY` |

Os dois primeiros usam a tag `tag:github` (o OAuth client precisa ter `auth_keys` e essa tag permitidos no console).
