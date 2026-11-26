# actions

Shared CI pieces for the `victor-software-house` repositories.
Each piece lives here once, and every repository that uses it pins one commit.

## Contents

| Path | What it is | Docs |
|:--|:--|:--|
| `mise/` | An action that installs the locked mise tools through the release mirror, with the job's OIDC token | [mise](mise/README.md) |
| `verify-jobs/` | An action that passes or fails a reusable workflow's one required check from the results of the jobs behind it | [verify-jobs](verify-jobs/README.md) |
| `mbx-cache/` | An action that sets mbx up with the organization's remote cache, with credentials the release mirror signs for the job | [mbx-cache](mbx-cache/README.md) |
| `build-scope/` | An action that decides whether a pull request or merge group changes anything the build reads | [build-scope](build-scope/README.md) |
| `prune-caches/` | An action that deletes every cache entry of each key prefix on the run's ref, except the newest | [prune-caches](prune-caches/README.md) |
| `post-oidc-token/` | An action that posts the job's OIDC token to a URL, with the URL as its audience, in up to five attempts | [post-oidc-token](post-oidc-token/README.md) |
| `publish-task-groups/` | An action that publishes each task group of a repository as a one-layer OCI artifact on GHCR when its content changed | [publish-task-groups](publish-task-groups/README.md) |
| `macos-signing/` | Actions that load and remove the macOS signing identities | [macos-signing](macos-signing/README.md) |
| `.github/workflows/rust-ci.yml` | A reusable workflow: Rust build, tests and checks behind one `Verify` job | [Rust CI](docs/rust-ci.md) |
| `.github/workflows/bun-ci.yml` | A reusable workflow: a Bun repository's `mise run verify` behind one `Verify` job | [Bun CI](docs/bun-ci.md) |
| `.github/workflows/mise-tasks-ci.yml` | A reusable workflow: a task-group repository's `mise run verify` behind one `Verify` job, and a `Publish` job that pushes each changed group to GHCR | [Mise tasks CI](docs/mise-tasks-ci.md) |
| `.github/workflows/nix-host.yml` | A reusable workflow: builds one NixOS system on a native runner and, in the merge queue, uploads the closure to an S3-compatible Nix cache | [Nix host](docs/nix-host.md) |
| `.github/workflows/template-check.yml` | A reusable workflow that fails when a newer template tag would change the repository | [Template check](docs/template-check.md) |
| `.github/workflows/secrets.yml` | A reusable workflow that scans commits for credentials with gitleaks | [Secrets scan](docs/secrets.md) |
| `.github/workflows/homebrew-tap-ci.yml` | A reusable workflow: `brew style` and `brew readall` over a Homebrew tap repository, behind one `Style` job; it needs no secrets | [Homebrew tap CI](docs/homebrew-tap-ci.md) |
| `.github/workflows/renovate.yml` | A reusable workflow that runs Renovate over the active repositories of one visibility, from the files in `renovate/` | [Renovate](docs/renovate.md) |
| `.github/workflows/homebrew-bump.yml` | A reusable workflow that bumps a tap's cask to a release by a merged pull request; needs the secrets `CHANGESET_VERSION_APP_CLIENT_ID` and `CHANGESET_VERSION_APP_PRIVATE_KEY` | [Homebrew bump](docs/homebrew-bump.md) |
| `tasks/rust.toml` | A mise task catalog with the standard Rust tasks | [Rust catalog](tasks/README.md#rust-catalog) |
| `tasks/swift.toml` | A mise task catalog with the standard Swift tasks | [Swift catalog](tasks/README.md#swift-catalog) |
| `tasks/template.toml` | A mise task catalog: `template:check`, `template:off` and `template:on` | [Template catalog](tasks/README.md#template-catalog) |
| `policy/` | Rego rules that conftest runs over a repository's workflows | [Workflow policy](policy/README.md) |

## Pin a commit

A caller names a full commit SHA, with `# main, <date>` as the comment:

```yaml
- uses: victor-software-house/actions/mise@<commit> # main, 2026-11-09
```

A change here reaches a repository only through a reviewed pin bump.
A tag, when one exists, is annotated and moves by patch only, from `v0.0.1`.
It sits on a merged `main` commit whose CI passed, and never moves.

## Shared task groups

A repository of shared mise task groups keeps each group as a directory under `groups/`.
Its `ci.yml` calls the [Mise tasks CI](docs/mise-tasks-ci.md) workflow, which runs `mise run verify` and, on a push to the default branch, publishes each changed group with [publish-task-groups](publish-task-groups/README.md).
Another repository includes a published group by its digest:

```toml
[task_config]
includes = ["oci::ghcr.io/<owner>/tasks-<group>@sha256:<digest>"]
```

## Checks

`mise run verify` runs every check CI runs:

| Task | Checks |
|:--|:--|
| `lint:workflows` | `jactionlint` over the workflows |
| `check:catalog` | `tasks/rust.toml` matches ctl-core v0.6.28's catalog, apart from the changes [tasks/README.md](tasks/README.md#rust-catalog) lists |
| `check:policy` | Every rule in `policy/` passes its tests, then the pins rule runs over this repository's workflows |
| `check:template-on` | `template:on` passes each `--data` answer to `copier update` as its own argument, and rejects a value without `=` and the keys `pieces` and `pieces_extra` |
| `check:docs-probes` | `check:docs` fails each probe crate that breaks the docs standard, and passes the rest |
