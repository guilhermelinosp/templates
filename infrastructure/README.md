# infrastructure

Gera `infra/` plana (`application.yaml` com Deployment e Service, e `kustomization.yaml`) para servicos
`hellnet-service`. Dentro do repositorio do servico:

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermelinosp/templates/latest/scripts/new-infra.sh | bash -s -- <app> [--no-service] [--db] [--tag v1.0.0] [--namespace fast] [--print-application]
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
| Cluster (uma vez) | `cluster-config-sync.yaml` (SA so de ConfigMap no ns `fast`) e `appproject.yaml` |

Nova app: crie o secret `CONFIG_<APP>`, adicione-a nas `options`, no `case` e no env do passo Config
de `deploy.yml`, e inclua o repositorio em `sourceRepos` do `appproject.yaml`.
O ArgoCD nao rastreia o ConfigMap: use `config=true` e `restart=true` ao mudar um valor.
