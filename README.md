# templates

> Central App-authenticated CI/CD rules and migration guidance: [CI-CONTROL-PLANE.md](CI-CONTROL-PLANE.md)

Reusable GitHub Actions workflows for .NET, Go, containers, Kubernetes, Terraform, AWS, DevSecOps, FinOps, and SRE.

All workflows run on **ubuntu-latest** (GitHub-hosted runners).

## Usage

```yaml
jobs:
  build:
    uses: guilhermelinosp/templates/.github/workflows/dotnet-build.yml@latest
```

Consumers call the reusable workflows at `@latest` (a tag that the `latest` workflow
keeps on the newest release), and third-party actions are referenced by version tag,
not by commit SHA.

## Hellnet control plane

These reusable workflows form the central automation plane for repositories that
opt in explicitly:

| Workflow | Capability | Write token |
|---|---|---|
| `auto-pr.yml` | one PR per supported branch, labels, no duplicate PRs | App: contents/issues/pull requests/workflows |
| `pr-policy.yml` | title, branch, workflow ownership and shell policy | none; read-only |
| `pr-report.yml` | one persistent Build/Tests/Schema/Shell/Security/CodeQL/Policy report | Octo STS token: issues/pull requests/checks |
| `release.yml` | repository semver, immutable bot tag and release notes | Octo STS token: contents |

There is no private key: write-capable jobs exchange their OIDC token for a short-lived
Octo STS token, and only this repository's workflows can mint it (see `CI-CONTROL-PLANE.md`).
Validators cannot mint tokens and must run with `contents: read` or empty permissions.
Automation PRs are authored by `octo-sts[bot]`; no workflow or release job merges its own PR.

---

## Workflows

### .NET

| Workflow | Description |
|---|---|
| `dotnet-build.yml` | Restore, build, test .NET solution |
| `dotnet-push.yml` | Pack, publish NuGet to GitHub Packages + NuGet.org, create release |
| `nuget-build.yml` | Restore, build, test (simplified, no version input) |
| `nuget-publish.yml` | Pack, publish NuGet to GitHub Packages + NuGet.org |
| `nuget-tag.yml` | Semver bump from conventional commits + git tag |
| `nuget-release.yml` | Create GitHub release from tag |
| `nuget-pipeline.yml` | Orchestration: build → tag → publish → release |

### Go

| Workflow | Description |
|---|---|
| `go-build.yml` | Go tidy, vet, lint (golangci-lint), build, test with cache |
| `go-quality.yml` | All-in-one PR gate: module integrity, vet, extra checks, race tests + coverage artifact, canonical-config lint, build, smoke |
| `govulncheck.yml` | stdlib vulnerability scan with call-graph reachability |
| `goreleaser-publish.yml` | Publish cross-platform binaries onto the release created by `release.yml`. A config do GoReleaser é buscada de `ci-templates` (branch `main`) |
| _CodeQL_ | kept **per-repo** (inline) — reusable variant triggers GitHub validation quirks across callers; see golang-cli/golang-api templates for the canonical copy |

### Node.js

| Workflow | Description |
|---|---|
| `node-build.yml` | npm install, lint, build, test with cache |

### Bash

| Workflow | Description |
|---|---|
| `shellcheck.yml` | ShellCheck (reviewdog, bloqueante no nível `error`) + shfmt (informativo: formatação não reprova o job) |

### Containers

| Workflow | Description |
|---|---|
| `buildah.yml` | Build and push container images with buildah |
| `buildx.yml` | Multi-arch build and push with docker buildx (SBOM + provenance) |
| `cosign.yml` | Sign container images with cosign (keyless, OCI referrers) |
| `trivy.yml` | Vulnerability scan with Trivy (SARIF output) |
| `push.yml` | Promote container images across tags with skopeo |
| `sbom.yml` | Generate SBOM with Anchore Syft (SPDX/CycloneDX) |
| `slsa.yml` | Generate SLSA provenance attestation |

### Kubernetes

| Workflow | Description |
|---|---|
| `helm-lint.yml` | Helm lint, template, kubeconform schema validation |
| `helm-publish.yml` | Package and publish Helm charts to OCI registry |
| `helm-docs.yml` | Auto-generate Helm chart README from values.yaml |
| `kustomize-validate.yml` | Kustomize build + kubeconform validation |
| `cd.yml` | CD de qualquer app: dispara o hub `tailscale.yml` (Tailscale por OIDC + ArgoCD REST) e espera o rollout |
| `conftest.yml` | OPA policy-as-code for Kubernetes configs |
| `kube-bench.yml` | CIS Kubernetes benchmark |
| `popeye.yml` | K8s cluster sanitizer |

### Terraform

| Workflow | Description |
|---|---|
| `terraform-validate.yml` | Terraform fmt, init, validate |
| `terraform-apply.yml` | Plan + apply with environment gating, OIDC support |
| `terraform-docs.yml` | Auto-generate Terraform docs on PR |
| `terraform-aws-auth.yml` | AWS OIDC auth for Terraform + validate |
| `infracost.yml` | Cloud cost estimation with PR comments |

### AWS

| Workflow | Description |
|---|---|
| `prowler.yml` | AWS CIS security benchmarking (OIDC auth) |

### DevSecOps

#### SAST

| Workflow | Description |
|---|---|
| `codeql.yml` _(per-repo)_ | CodeQL analysis — kept inline per repo (reusable variant has unresolved validation quirk; canonical copy lives in golang-cli/golang-api templates) |
| `semgrep.yml` | Semgrep SAST (configurable rules) |
| `gosec.yml` | Go security static analysis |

#### DAST

| Workflow | Description |
|---|---|
| `zap.yml` | OWASP ZAP baseline/full scan |
| `nuclei.yml` | ProjectDiscovery nuclei vulnerability scanner |
| `dast.yml` | Orquestra ZAP e Nuclei contra uma `target-url` já no ar. Espera o alvo responder (`scripts/wait-for-url.sh`, TLS validado; `target-ca-cert` para CA própria) e roda os dois scanners. Exige `templates-ref`. Sem infraestrutura de preview |

#### Supply Chain

| Workflow | Description |
|---|---|
| `grype.yml` | Anchore Grype vulnerability scanner |
| `osv-scanner.yml` | Google OSV dependency scanner |
| `dependency-review.yml` | License + vulnerability review on PRs |

#### IaC Security

| Workflow | Description |
|---|---|
| `kics.yml` | Checkmarx KICS IaC scanning |

#### Secrets

| Workflow | Description |
|---|---|
| `gitleaks.yml` | Git secret scanning |
| `trufflehog.yml` | Additional secret scanning |

#### Repository

| Workflow | Description |
|---|---|
| `scorecard.yml` | OpenSSF Scorecard |

#### Bloqueante ou informativo

Nota: o `zap.yml` não aceita mais limiar de severidade. O gate é o `fail_action: true` do scanner, que não é configurável por input.

Nota: o `nuclei.yml` não tem gate verificado. Os achados sobem em SARIF para o Code Scanning e não reprovam o job; não confirmei no action pinado se existe opção de falha por severidade.


Classificação pelo que o YAML faz (não pelo que o action faz por padrão):

- **Informativo** (não bloqueia o PR): `osv-scanner.yml` (`|| true`), `trivy.yml` (`continue-on-error`).
- **Com gate explícito** (falha o job): `zap.yml`, `grype.yml`, `kics.yml`, `dependency-review.yml`.
- **Não classificado**: `codeql`, `semgrep`, `gosec`, `nuclei`, `gitleaks`, `trufflehog`, `scorecard`. O comportamento depende da configuração padrão de cada action; confirme no GitHub antes de contar com eles como barreira.

#### Verificação local
- Compliance do `branch-rules.yml`: `scripts/tests/branch-rules/run.sh` (15 cenários com `gh` falso: violação, erro HTTP, JSON inválido, árvore truncada, campo ausente, base64 inválido; sucesso só com consulta válida sem violação). Requer ruby e jq.
- Readiness: `scripts/tests/wait-for-url/run.sh` (8 casos: HTTP, HTTPS autoassinado com e sem CA, TLS nunca vira pronto; usa node e openssl locais).

- Exceções de vulnerabilidade: `scripts/tests/vuln-exceptions/run.sh` (8 casos: válidos passam; expirada, sem dono, escopo genérico, data inválida, chave com typo, arquivo vazio e escopo `all` falham) e `scripts/check-vuln-exceptions.sh security/vuln-exceptions.yml` (arquivo real). Nenhum workflow do repositório executa esses testes: rode-os antes de alterar o validador. Workflow reutilizável: `vuln-exceptions.yml`.
- Políticas Kubernetes (Conftest/Rego, `policy/kubernetes/security.rego`): `conftest verify --policy policy/kubernetes` roda os testes unitários (8 casos, incluindo CronJob); `conftest test <manifesto.yaml> --policy policy/kubernetes --namespace kubernetes` avalia um manifesto. Cobre Pod, Deployment, StatefulSet, DaemonSet, ReplicaSet, Job e CronJob. `policy/kubernetes/testdata/invalid-deployment.yaml` é fixture inválido de propósito.
- Workflows: `actionlint .github/workflows/*.yml` e `zizmor --config .github/zizmor.yml .github/workflows/`. O zizmor desliga só `unpinned-uses`, por preferência de tags em vez de SHA.
- Política Kyverno de imagens (`policy/kyverno/verify-images.yaml`, tipo `ImageValidatingPolicy`): `kubectl apply --dry-run=server -f policy/kyverno/verify-images.yaml` valida o schema e o CEL no cluster sem criar nada. `kyverno apply policy/kyverno/verify-images.yaml --resource <pod.yaml>` testa offline a regra de digest (tag mutável é negada). A regra de assinatura não é verificada offline: retorna `error` sem detalhe quando o registry não responde.

#### Limitações conhecidas e requisitos externos

- **Verificações em runner real.** `self-test.yml` (manual, `workflow_dispatch`) roda exceções, readiness, o validador por workflow reutilizável e os testes do passo de compliance. Os demais workflows são validados localmente (YAML, actionlint, zizmor, conftest, dry-run do Kyverno) e em PRs. Publicação NuGet, DAST contra alvo real e verificação de assinatura Kyverno ainda não foram executados.
- **Assinatura Cosign não verificada de ponta a ponta.** Exige uma imagem assinada pelo `cosign.yml` e acesso de leitura ao `ghcr.io`.
- **Scripts vêm do `templates-ref`.** `dast.yml` e `vuln-exceptions.yml` exigem `templates-ref` (tag ou SHA do repositório templates). Passe a mesma versão usada em `uses:`. Não há checagem automática de que as duas coincidem.
- **Actions por tag, não por SHA.** Por decisão do mantenedor; o zizmor desliga só `unpinned-uses`. Alguns workflows herdados já usam SHA, então a convenção não é uniforme.
- **`self-repository` (baixa):** o zizmor sugere `$/` em vez de `./` nas chamadas locais. O actionlint rejeita `$/` como formato inválido de referência, então `./` é a única forma aceita. Os três pontos têm `zizmor: ignore` com esse motivo.
- **Testes que só rodam no GitHub Actions:** `self-test.yml` (manual, `gh workflow run self-test.yml`) roda exceções, readiness e a chamada real do workflow de exceções. Não foi executado ainda. Publicação NuGet, artifacts do ZAP, DAST contra alvo real e verificação de assinatura Kyverno exigem secrets, registry ou alvo próprio e não estão cobertos.
- **Relatórios de DAST.** ZAP publica relatórios como artifact (sem SARIF). Nuclei envia SARIF e não tem gate verificado. A CA de `target-ca-cert` vale só para a espera: os scanners validam o certificado por conta própria.
- **`goreleaser-publish.yml`:** zizmor sem achados neste arquivo. A config do GoReleaser vem de `ci-templates@main` (implícito, mantido por ser comportamento de publicação).

### FinOps

| Workflow | Description |
|---|---|
| `infracost.yml` | Terraform cloud cost estimation |
| `kube-resource.yml` | Analyze K8s resource requests/limits |

### Automation

| Workflow | Description |
|---|---|
| `auto-pr.yml` | Auto-create/update PR to main from feature branches |
| `merge-check.yml` | Validate merge strategy, conventional commits |
| `labeler.yml` | Auto-label PRs by changed paths |
| `dependabot-auto-merge.yml` | Auto-approve + squash low-risk Dependabot PRs |
| `stale.yml` | Stale issue/PR management |
| `renovate.yml` | Renovate dependency update automation |
| `commit-lint.yml` | Validate PR commits follow conventional commits |

### Release

| Workflow | Description |
|---|---|
| `release.yml` | Semver bump, immutable bot tag, GitHub release and generated notes |
| `pipeline.yml` | Push-to-main pipeline: release → build → push |

#### Signed release tags

Release versioning is repository semver only. Schema identity remains owned by
the schema repository (for example `schemas/avro/fast-ride-completed/v1`) and is
never inferred from the repository release number. Version tags are immutable;
the workflow fails if a tag already points at another commit and never updates a
mutable `latest` tag.

- Public key for verification: [`signing-key.asc`](signing-key.asc)
  (`gpg --import signing-key.asc && git verify-tag v1.2.3`)
- Enrolled repos: hellnet-lib-cache, hellnet-lib-kafka, hellnet-lib-telemetry,
  golang-lib-template

> ⚠️ The account is personal (no org-level secrets), so each repo carries its
> own copy of the secret. Use
> [`scripts/sync-gpg-release-secret.sh`](scripts/sync-gpg-release-secret.sh)
> to set/rotate it across all repos in one command. Keep a backup of the
> private key outside GitHub — Actions secrets are write-only.

### AI

| Workflow | Description |
|---|---|
| `ai-review.yml` | AI-powered code review via OpenAI API (PR comments) |

### Code Review

| Workflow | Description |
|---|---|
| `reviewdog.yml` | Automated PR comments (golangci-lint, misspell, shellcheck) |

---

## Patterns

### Passing inputs

```yaml
jobs:
  scan:
    uses: guilhermelinosp/templates/.github/workflows/trivy.yml@latest
    with:
      image: ghcr.io/org/app@sha256:abc123
```

### Passing secrets

```yaml
jobs:
  deploy:
    uses: guilhermelinosp/templates/.github/workflows/cd.yml@latest
    with:
      app: my-app
      version: ${{ needs.release.outputs.version }}
    secrets: inherit
```

### Chaining workflows

```yaml
jobs:
  lint:
    uses: guilhermelinosp/templates/.github/workflows/shellcheck.yml@latest

  build:
    needs: [lint]
    uses: guilhermelinosp/templates/.github/workflows/go-build.yml@latest

  scan:
    needs: [build]
    uses: guilhermelinosp/templates/.github/workflows/gitleaks.yml@latest
```

---

## Principles

- **No self-hosted runners** — all workflows run on `ubuntu-latest`
- **Least privilege** — minimal `permissions:` on every workflow
- **SARIF quando a ferramenta suporta** — ex.: trivy e nuclei enviam SARIF ao Code Scanning. O ZAP não gera SARIF: publica relatórios como artifact do próprio action.
- **Conventional Commits** — semver bump depends on commit messages
- **Reusable** — opt-in workflows are `workflow_call` for composition
- **Safe writes** — bot writes use the Octo STS token (OIDC, no stored key); `GITHUB_TOKEN` remains read-only where possible
