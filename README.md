# templates

Reusable GitHub Actions workflows for .NET, Go, containers, Kubernetes, Terraform, AWS, DevSecOps, FinOps, and SRE.

All workflows run on **ubuntu-latest** (GitHub-hosted runners).

## Usage

```yaml
jobs:
  build:
    uses: guilhermelinosp/templates/.github/workflows/dotnet-build.yml@<full-commit-sha>
```

Production consumers pin reusable workflows to a full commit SHA. Tags and `@main`
are for exploration only.

## Hellnet control plane

These reusable workflows form the central automation plane for repositories that
opt in explicitly:

| Workflow | Capability | Write token |
|---|---|---|
| `auto-pr.yml` | one PR per supported branch, labels, no duplicate PRs | App: contents/issues/pull requests/workflows |
| `pr-policy.yml` | title, branch, workflow ownership and shell policy | none; read-only |
| `pr-report.yml` | one persistent Build/Tests/Schema/Shell/Security/CodeQL/Policy report | App: issues/pull requests/checks |
| `release.yml` | repository semver, immutable bot tag and release notes | App: contents |
| `maintenance.yml` | pin refresh PRs using Contents API commits | App: contents/issues/pull requests/workflows |

The private key is accepted only by write-capable jobs. Validators do not receive
it and must run with `contents: read` or empty permissions. Workflow changes are
required to arrive through a PR authored by `hellnet-actions[bot]`; no workflow
or release job merges its own PR.

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
| `goreleaser.yml` | Publish cross-platform binaries onto the release created by `release.yml` |
| _CodeQL_ | kept **per-repo** (inline) — reusable variant triggers GitHub validation quirks across callers; see golang-cli/golang-api templates for the canonical copy |

### Node.js

| Workflow | Description |
|---|---|
| `node-build.yml` | npm install, lint, build, test with cache |

### Bash

| Workflow | Description |
|---|---|
| `shellcheck.yml` | ShellCheck + shfmt formatting check |

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
| `deploy.yml` | Helm upgrade via kubeconfig secret + rollout verification |
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
| `sonarcloud.yml` | SonarCloud analysis with PR decoration |

#### DAST

| Workflow | Description |
|---|---|
| `zap.yml` | OWASP ZAP baseline/full scan |
| `nuclei.yml` | ProjectDiscovery nuclei vulnerability scanner |

#### Supply Chain

| Workflow | Description |
|---|---|
| `grype.yml` | Anchore Grype vulnerability scanner |
| `snyk.yml` | Snyk vulnerability scanning + monitor |
| `osv-scanner.yml` | Google OSV dependency scanner |
| `owasp-dependency-check.yml` | OWASP Dependency Check |
| `dependency-review.yml` | License + vulnerability review on PRs |

#### IaC Security

| Workflow | Description |
|---|---|
| `checkov.yml` | Bridgecrew IaC scanning (Terraform, K8s, Dockerfile) |
| `tfsec.yml` | Terraform security scanner |
| `kics.yml` | Checkmarx KICS IaC scanning |

#### Container Security

| Workflow | Description |
|---|---|
| `dockle.yml` | Docker CIS benchmark linter |

#### Secrets

| Workflow | Description |
|---|---|
| `gitleaks.yml` | Git secret scanning |
| `trufflehog.yml` | Additional secret scanning |

#### Repository

| Workflow | Description |
|---|---|
| `scorecard.yml` | OpenSSF Scorecard |

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
  hellnet-lib-environments, golang-lib-template

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
    uses: guilhermelinosp/templates/.github/workflows/trivy.yml@<full-commit-sha>
    with:
      image: ghcr.io/org/app@sha256:abc123
```

### Passing secrets

```yaml
jobs:
  deploy:
    uses: guilhermelinosp/templates/.github/workflows/deploy.yml@<full-commit-sha>
    with:
      namespace: production
      release-name: my-app
    secrets:
      KUBECONFIG: ${{ secrets.KUBECONFIG }}
```

### Chaining workflows

```yaml
jobs:
  lint:
    uses: guilhermelinosp/templates/.github/workflows/shellcheck.yml@<full-commit-sha>

  build:
    needs: [lint]
    uses: guilhermelinosp/templates/.github/workflows/go-build.yml@<full-commit-sha>

  scan:
    needs: [build]
    uses: guilhermelinosp/templates/.github/workflows/gitleaks.yml@<full-commit-sha>
```

---

## Principles

- **No self-hosted runners** — all workflows run on `ubuntu-latest`
- **Least privilege** — minimal `permissions:` on every workflow
- **SARIF everywhere** — security tools output SARIF for GitHub Security tab
- **Conventional Commits** — semver bump depends on commit messages
- **Reusable** — opt-in workflows are `workflow_call` for composition
- **Safe writes** — bot writes use the `hellnet-actions` installation token; `GITHUB_TOKEN` remains read-only where possible
- **Immutable history** — maintenance commits are created through the Contents API and checked with `verification.verified == true`
