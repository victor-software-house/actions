# actions

Shared CI pieces for the `victor-software-house` repositories.
Each piece lives here once, and every repository that uses it pins one commit.

## Contents

| Path | What it is | Docs |
|:--|:--|:--|
| `mise/` | An action that installs the locked mise tools through the release mirror, with the job's OIDC token | [mise](mise/README.md) |
| `macos-signing/` | Actions that load and remove the macOS signing identities | [macos-signing](macos-signing/README.md) |
| `.github/workflows/rust-ci.yml` | A reusable workflow: Rust build, tests and checks behind one `Verify` job | [Rust CI](docs/rust-ci.md) |
| `.github/workflows/template-check.yml` | A reusable workflow that fails when a newer template tag would change the repository | [Template check](docs/template-check.md) |
| `.github/workflows/secrets.yml` | A reusable workflow that scans commits for credentials with gitleaks | [Secrets scan](docs/secrets.md) |
| `tasks/rust.toml` | A mise task catalog with the standard Rust tasks | [Rust catalog](tasks/README.md#rust-catalog) |
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

## Checks

`mise run verify` runs every check CI runs:

| Task | Checks |
|:--|:--|
| `lint:workflows` | `actionlint` over the workflows |
| `check:pins` | Every `uses:` names a full commit SHA with a version comment |
| `check:catalog` | `tasks/rust.toml` matches ctl-core v0.6.28's catalog, apart from the changes [tasks/README.md](tasks/README.md#rust-catalog) lists |
| `check:policy` | Every rule in `policy/` passes its tests, then the pins rule runs over this repository's workflows |
| `check:docs-probes` | `check:docs` fails each probe crate that breaks the docs standard, and passes the rest |
