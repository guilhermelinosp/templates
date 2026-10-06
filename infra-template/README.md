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
