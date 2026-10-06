# infra-template

Estrutura de deploy (Kustomize + ArgoCD) para servicos `hellnet-service`.
Gere dentro do repositorio do servico:

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermelinosp/templates/latest/scripts/new-infra.sh | bash -s -- <app> [--no-service] [--db] [--tag v1.0.0] [--namespace fast]
```

Cria `infra/` (base + overlay homelab + Application) e, em `.github/workflows/`,
os chamadores finos de `argocd.yml` e `infra-validate.yml` (`@latest` deste repositorio).
Nao sobrescreve nada que ja exista.

## Ajustes por app (nao vem do gerador)

O gerador usa padroes seguros. Ajuste em `infra/base/deployment.yaml` o que for especifico:
`strategy` (ex. `Recreate` para consumers singleton), limites de CPU/memoria e `config.env`.
Se o servico usa banco, `--db` referencia o secret `fast-database` por nome (nao versionado).

## Credenciais do deploy (automatico)

- `scripts/bootstrap-repo.sh <owner/repo>`: poe o topico `hellnet-deploy`, define as variables,
  grava os secrets lidos do **ambiente** (nada em arquivo), cria o environment `production`
  (revisor + so `main`) e exige aprovacao de colaboradores externos. `DRY_RUN=1` so mostra.
- `new-infra.sh ... --bootstrap` faz as duas coisas de uma vez.
- Workflow `sync-secrets` (manual e semanal): propaga `TS_OAUTH_SECRET` e `ARGOCD_TOKEN` guardados
  neste repositorio para todo repositorio com o topico `hellnet-deploy`. Para rotacionar, atualize
  os secrets aqui e rode o workflow. Requer o GitHub App com permissao de Secrets.
