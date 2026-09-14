# Hellnet Actions CI control plane

`guilhermelinosp/templates` is the reusable-workflow control plane for the `guilhermelinosp` repositories. Consumers must pin this repository to a full commit SHA:

```yaml
jobs:
  ci:
    uses: guilhermelinosp/templates/.github/workflows/go-quality.yml@<FULL_COMMIT_SHA>
```

Do not use `@main`, release tags, or other floating refs for production workflows.

## Write-capable workflows

| Workflow | Operation | Token | Permissions |
| --- | --- | --- | --- |
| `auto-pr.yml` | create or update a PR and push a controlled branch | `hellnet-actions` installation token | `contents: write`, `pull-requests: write` |
| `labeler.yml` | apply path-based labels | `hellnet-actions` installation token | `pull-requests: write` |
| `pr-report.yml` | create or update the persistent CI comment (informational only) | `hellnet-actions` installation token | `issues: write`, `pull-requests: read` |
| `release.yml` | create an immutable release tag and GitHub Release | `hellnet-actions` installation token | `contents: write` |

`pr-report.yml` is not a validation gate. It reports the status of checks that already ran and never creates an artificial check-run or blocks a pull request.

Each write-capable reusable workflow requires the caller to pass `app-id: ${{ vars.HELLNET_ACTIONS_CLIENT_ID }}` and `secrets: inherit`. The caller repository must contain `HELLNET_ACTIONS_PRIVATE_KEY` and the App must be installed there.

Read-only validators keep `permissions: contents: read` and do not receive the App private key. They include lint, tests, schema validation, ShellCheck, secret scanning, CodeQL, and policy checks.

## Human and automation planes

Human commits retain their original author and signature. Bot-generated writes use the GitHub App installation token. The schema generator uses the Git Database API and stops when GitHub reports `verification.verified` as false. Automatic tags are created once through the GitHub API and fail if an existing tag points to another commit; no force push is used.

The reporter uses the marker `<!-- hellnet-actions-report -->` and updates that one issue comment instead of creating comment spam.

## Security boundary

Never expose `HELLNET_ACTIONS_PRIVATE_KEY` to code from an untrusted pull request. Write-capable jobs must not checkout or execute pull request code. Do not use `pull_request_target` for code execution. The bot may create, update, label, validate, and request review; it must not approve its own pull request, bypass required checks, or alter repository rulesets.

## Migration order

1. Merge the control-plane changes and record the resulting commit SHA.
2. Update one consumer, starting with `hellnet-lib-schema`, to pass the App credentials and pin every reusable workflow to that SHA.
3. Verify the bot PR creator, API commit verification, reporter update, labels, immutable tag, and release attribution.
4. Migrate the remaining consumers in small pull requests.
