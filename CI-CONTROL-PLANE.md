# Hellnet Actions CI control plane

`guilhermelinosp/templates` is the reusable-workflow control plane for the `guilhermelinosp` repositories. Consumers reference this repository by `@latest`, a tag that the `latest` workflow keeps on the newest release (the GitHub "Latest release"):

```yaml
jobs:
  ci:
    uses: guilhermelinosp/templates/.github/workflows/go-quality.yml@latest
```

Actions are referenced by version tag (for example `actions/checkout@v7`), not by commit SHA. A change merged here reaches every consumer immediately, so review changes to this repository as production changes.

## Write-capable workflows

| Workflow | Operation | Token | Permissions |
| --- | --- | --- | --- |
| `auto-pr.yml` | create or update a PR and push a controlled branch | Octo STS token (OIDC, no private key) | `contents: write`, `pull-requests: write` |
| `labeler.yml` | apply path-based labels | Octo STS token (OIDC, no private key) | `pull-requests: write` |
| `pr-report.yml` | create or update the persistent CI comment (informational only) | Octo STS token (OIDC, no private key) | `issues: write`, `pull-requests: read` |
| `release.yml` | create an immutable release tag and GitHub Release | Octo STS token (OIDC, no private key) | `contents: write` |

`pr-report.yml` is not a validation gate. It reports the status of checks that already ran and never creates an artificial check-run or blocks a pull request.

Write-capable reusable workflows get their token from [Octo STS](https://github.com/octo-sts/app) by exchanging the job's OIDC token, so **no private key or secret is stored anywhere**. The caller only needs `id-token: write` on the calling job/workflow and the Octo STS GitHub App installed on the repository. Each repository holds trust policies in `.github/chainguard/<identity>.sts.yaml` (`auto-pr`, `release`, `labeler`, `pr-report`); each policy is bound to the repository subject and to the `job_workflow_ref` of the matching workflow in this repository, so only this control plane can mint the token (a plain workflow in the consumer asking for the same identity is denied). Deploys (`cd.yml`) ask for a token scoped to this repository through `.github/chainguard/cd.sts.yaml`. The old `app-client-id`/`app-id` inputs are obsolete and ignored.

Read-only validators keep `permissions: contents: read` and cannot mint tokens. They include lint, tests, schema validation, ShellCheck, secret scanning, CodeQL, and policy checks.

## Human and automation planes

Human commits retain their original author and signature. Bot-generated writes use the Octo STS token (author `octo-sts[bot]`). The schema generator uses the Git Database API and stops when GitHub reports `verification.verified` as false. Automatic tags are created once through the GitHub API and fail if an existing tag points to another commit; no force push is used.

The reporter uses the marker `<!-- hellnet-actions-report -->` and updates that one issue comment instead of creating comment spam.

## Security boundary

Never widen an Octo STS policy beyond the `job_workflow_ref` of a workflow in this repository. Write-capable jobs must not checkout or execute pull request code. Do not use `pull_request_target` for code execution. The bot may create, update, label, validate, and request review; it must not approve its own pull request, bypass required checks, or alter repository rulesets.

## Adding a repository

1. Install the Octo STS GitHub App on the repository.
2. Copy `.github/chainguard/*.sts.yaml` from another consumer and replace the repository name in `subject_pattern`.
3. Grant `id-token: write` to the callers (`pipeline.yml`, `pr-check.yml`, `auto-pr.yml`).
