# infrastructure

Gera `infrastructure/` plana (`application.yml` com Deployment e Service, e `kustomization.yml`) para servicos
`hellnet-service`. Dentro do repositorio do servico:

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermelinosp/templates/latest/scripts/new-infra.sh | bash -s -- <app> [--no-service] [--db] [--namespace fast] [--print-application]
```

Nao sobrescreve nada que ja exista. O chamador `infra-validate` vai para `.github/workflows/`.

## Deploy, secrets e config: tudo no templates

Os repositorios dos servicos nao guardam secret, variable nem config. Tudo fica nas configuracoes
**deste** repositorio (`templates`) e o deploy sai de `deploy.yml`:

```bash
gh workflow run deploy.yml -R guilhermelinosp/templates -f app=fast-platform -f tag=v1.2.3 -f action=sync -f config=true
```

| Onde | O que |
|---|---|
| Secrets | `TS_AUTHKEY`, `ARGOCD_TOKEN`, `KUBE_TOKEN`, `KUBE_CA`, `CONFIG_<APP>` (conteudo do env da app) |
| Variables | `ARGOCD_SERVER`, `K8S_API_HOST` |
| Cluster (uma vez) | `cluster-config-sync.yml` (SA so de ConfigMap no ns `fast`) e `appproject.yml` |

Nova app: crie o secret `CONFIG_<APP>`, adicione-a nas `options`, no `case` e no env do passo Config
de `deploy.yml`, e inclua o repositorio em `sourceRepos` do `appproject.yml`.
O ArgoCD nao rastreia o ConfigMap: use `config=true` e `restart=true` ao mudar um valor.

## Versao da imagem: sempre a ultima, sem bump

A versao NAO fica no Git (`image:` sem tag). O **ArgoCD Image Updater** (`image-updater.yml`) acompanha o GHCR
e grava a ultima tag semver direto na `Application` (write-back `argocd`: sem commit e sem PR). So considera
tags que ja existem no registry, entao uma release cuja imagem ainda esta sendo construida nao e implantada.

- Instalar (uma vez): `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/v1.3.0/config/install.yaml`
  e depois `kubectl apply -f infrastructure/image-updater.yml`.
- Rollback ou pausa: no `ImageUpdater`, `commonUpdateSettings.ignoreTags: "*"` (pausa) e `deploy.yml` com `tag=vX.Y.Z`.
- Merges so de `infrastructure/**` nao geram release nem imagem (`paths-ignore` no `pipeline.yml` do servico).
