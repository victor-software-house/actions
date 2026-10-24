# actions

Shared CI logic and mise task catalogs, called by commit from the repositories
that use them.
Logic that is identical everywhere lives here once; each repository carries
only the line that pins it.

## Contents

| Path | Holds |
|:--|:--|
| `tasks/rust.toml` | The standard Rust tasks: `check:toolchain`, `format`, `lint`, `test`, `test:doc`, `deny`, `deny:advisories`, `deps`, `check:versions`, `semver`, `doc`, and `check:docs` |
| `.github/workflows/rust-ci.yml` | The reusable Rust CI workflow: a `Verify` job that runs `mise run verify`, then the network checks, or only the documentation checks for a documentation-only pull request |
| `tasks/template.toml` | `template:check`, which fails when the newest tag of the repository's Copier template would change it, and `template:off` and `template:on`, which turn template pieces off and on |
| `.github/workflows/template-check.yml` | The reusable drift check: a `Template` job that runs `template:check` with a token that reads the template, skipped for a pull request that touches none of the caller's `paths` |

## Use the Rust catalog

Include the catalog by commit in `mise.toml`, after `mise-tasks`, and set the
toolchains it reads:

```toml
[settings]
# mise loads git:: task includes only in experimental mode.
experimental = true

[env]
# format runs on this toolchain when set, for rustfmt's unstable options.
RUSTFMT_TOOLCHAIN = "+nightly-2026-09-29"
# doc builds on this nightly, as docs.rs does.
RUST_NIGHTLY = "nightly-2026-09-29"

[task_config]
includes = [
  "mise-tasks",
  "git::https://github.com/victor-software-house/actions.git//tasks/rust.toml?ref=<commit>",
]
```

The catalog names no toolchain version and defines no `verify`.
Each repository pins its own tools and composes `verify` from the tasks it
runs, beside its own `check:features` and `check:repo`.
`format` runs `cargo fmt` on the pinned stable when `RUSTFMT_TOOLCHAIN` is
unset.
`doc` runs `cargo +$RUST_NIGHTLY doc --no-deps --all-features --locked` with
`RUSTDOCFLAGS="--cfg docsrs -D warnings"`, so a rustdoc warning fails it before
docs.rs sees it.
It builds every feature even when a crate's docs.rs metadata lists fewer, so it
checks every gated item docs.rs could render.
`check:docs` checks what `doc` cannot see, for a repository that publishes.
Every library cargo would publish sets `rustdoc-args = ["--cap-lints", "warn"]`
in `[package.metadata.docs.rs]`, and chooses what docs.rs builds:
`all-features = true`, or a `features` list when all features would build
heavy dependencies that gate no documented item.
Every such library with a feature besides `default` carries
`#![cfg_attr(docsrs, feature(doc_cfg))]` at its crate root.
No tracked Rust, TOML, or shell file, and no file in a mise file-task
directory, names `clippy::missing_{errors,panics}_doc` or `clippy::pedantic` at any
level: a crate names them only to change their level.
A `[lints]` key fails for either lint at any level, and for `pedantic` at
`allow`.
It runs `cargo metadata`, `jq`, and `git grep`, so the repository pins `jq`.
`check:versions` fails when a manifest version changed outside a Version PR.
It passes with a notice when the repository has no `.ctl/ver.yaml` and
`VERCTL_CONFIG` is unset, and fails when `VERCTL_CONFIG` names no file.
A repository that declares releases includes verctl's `ver` task, which it
calls.
`semver` also runs through `ver` (`mise run ver semver`), at the release type
the pending fragments allow, so a published crate includes `ver` too.
It fails when the release config is missing.
`lint`, `test`, and `test:doc` pass `--workspace`, so every member of a
workspace is checked, not only its root package.
An inline `[tasks.<name>]` in `mise.toml` replaces a catalog task of the same
name.

## Call the Rust CI workflow

A repository's `ci.yml` calls the workflow by commit, with the mise release it
pins:

```yaml
jobs:
  verify:
    uses: victor-software-house/actions/.github/workflows/rust-ci.yml@<commit> # <tag>
    with:
      mise-version: 2026.10.17
```

The job runs on `ubuntu-latest` for a public repository and on the Namespace
runner for a private one, read from the calling repository's visibility.
It checks out the repository with its submodules, installs the locked tools
with mise, restores mbx's compiled objects, and runs `mise run verify` with
`MISE_ENV=ci` and git's first branch set to `main`.
A cache step that fails, such as a save refused because the commit's key is already reserved on a re-run, does not fail the job: the result comes from the build and tests.
The build cache follows the runner the job lands on, and no input chooses it.
On Namespace the job runs with a cache volume tagged `rust-<repository>`,
sized by `cache-size`, and keeps mise's installs, rustup's toolchains, Cargo's
home, `target/`, and mbx's store on it; the job commits the volume when it
exits cleanly, and the next job forks the newest commit.
A pull request reads the volume and never commits it, so only reviewed code
(a push, a merge queue run, a dispatch) writes the toolchains and the store
that every later build runs.
A last step keeps the volume under its size: `mbx gc` holds the store to a
third of it after a passing build, and `target/` is emptied once it passes half.
On a GitHub-hosted runner the job restores the mise install cache and mbx's
objects from the GitHub Actions cache instead.
Each step has its own time limit and the job has none, so the job ends within
their sum.
The mbx step's 7 minutes apply to the restore and to the export separately,
and a failed or timed-out export leaves the job green.
The export removes the Cargo target first, after every step that reads it.
A step the workflow does not run, such as a release build, goes in a job of
the calling workflow beside the call.

A pull request runs only the tests its diff can reach; a merge queue run, a
push and a dispatch run every test.
Each changed file belongs to the deepest workspace package whose directory
holds it, and the selection is those packages and every package that depends
on them through a path dependency of any kind.
A file that belongs to no package, such as `Cargo.lock` or a workflow,
selects every test.
The selection reaches the repository's `test` task as a nextest filterset in
`TEST_FILTERSET` (`package(=a) | package(=b)`), so a task that runs
`cargo nextest run --workspace` passes it with `-E` and `--no-tests=pass`;
the catalog's `cargo test` ignores it and runs everything.
The whole workspace still builds: building fewer packages resolves features
per package and rebuilds dependencies the full build already has.

A pull request that changes only documentation builds nothing.
A `Changes` job on `ubuntu-latest` reads the changed paths with
[dorny/paths-filter](https://github.com/dorny/paths-filter).
Documentation is the root's Markdown files, `docs/`, and `openspec/`,
except a file a Rust source names by its repository path, alone or at the
end of a relative path, as a test or an `include_str!` that reads it does.
For such a pull request, `Verify` runs on `ubuntu-latest`, installs the tools
without Rust, and runs whichever of `lint:md`, `lint:typos`, and `specs` the
repository defines.
With `semver`, every pull request builds: `cargo package` ships documentation
files, and the `Package` step checks it.
The check keeps its name and reports a result either way.
A push to the default branch always builds, so the mbx cache saved from it
stays current.

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the crate's `mise.toml` |
| `advisories` | `true` | Runs `mise run deny:advisories` after `verify` |
| `semver` | `false` | Runs `mise run semver` and `cargo package`, for a published crate |
| `timeout-minutes` | `8` | Cancels a hung `Verify`, `Semver` or `Package` step |
| `cache-size` | `50` | Size in GB of the Namespace cache volume a private repository's build mounts |

## Check the template version

Include the template catalog by commit, beside the Rust catalog:

```toml
[task_config]
includes = [
  "mise-tasks",
  "git::https://github.com/victor-software-house/actions.git//tasks/template.toml?ref=<commit>",
]
```

`mise run template:check` reads `_src_path` and `_commit` from
`.copier-answers.yml`, runs `copier update` to the template's newest `vX.Y.Z`
tag, and fails when that changes any file besides the answers file.
A newer tag that renders no change passes with a notice.
With `TEMPLATE_DRIFT=notice` a tag that changes files passes with a notice
too, and leaves the update in the working tree.
Copier runs through `uvx`, at the version the template pins as
`"pypi:copier"` in its own `mise.toml` at that tag.
The task declares uv and python in its `tools` table, and `mise lock` records
them in the repository's lock.

The CI workflow runs on pull requests, on merge queue entries, and daily,
and calls the drift-check workflow by commit, passing only the
template-reader App's private key:

```yaml
on:
  pull_request:
  merge_group:
  schedule:
    - cron: "17 9 * * *"

jobs:
  template:
    uses: victor-software-house/actions/.github/workflows/template-check.yml@<commit> # <tag>
    permissions:
      contents: read
      issues: write
    with:
      mise-version: 2026.10.17
    secrets:
      TEMPLATES_APP_PRIVATE_KEY: ${{ secrets.TEMPLATES_APP_PRIVATE_KEY }}
```

Only an update pull request, one that changes `.copier-answers.yml`, fails
when the newest tag would change the repository.
Every other pull request passes with a notice, so a new tag fails no
unrelated pull request.
A merge queue entry skips the check, which its pull request already ran;
the skipped job reports success, so a ruleset that requires it lets the
entry land.
A push to the default branch runs nothing.
The scheduled run opens an issue titled "Template update available"
(with " in <directory>" below the root) that lists the files the newest tag
changes, updates it on later runs, and closes it once the repository is on
a tag that leaves nothing to update.
A repository with issues turned off gets the notice only.

The workflow mints a read-only token for the template repository from a
GitHub App, with the client ID in the organization variable
`TEMPLATES_APP_CLIENT_ID` and the key in the organization secret
`TEMPLATES_APP_PRIVATE_KEY`.
It passes the token only to the step that runs `template:check`.
It takes `working-directory` for a template rendered below the repository
root, and skips a pull request from a fork, which gets no secrets.

`paths` lists the files the template renders, one glob per line, relative to
`working-directory`.
A pull request that changes none of them skips the check: a `Changes` job on
`ubuntu-latest` diffs the merge commit against its base with git's glob
pathspecs, where `*` stays within one directory and `**` crosses them.
The skipped `Template` job still reports, so a branch rule that requires
`template / Template` passes.
Pushes and scheduled runs always check.
Without `paths`, every pull request checks.

## Turn a template piece off or on

The template answers `pieces` and `pieces_extra` list the pieces it manages.
A plain `copier update --data` that drops a piece deletes the piece's files,
edited or not, so change the lists through these tasks:

```sh
mise run template:off deny
mise run template:on deny
```

`template:off` renders the recorded template version with and without the
pieces, and takes the files that disappear.
It then runs `copier update --vcs-ref=:current:` without the pieces and with
one `--exclude` for each of those files.
The repository keeps its copies and owns them from then on: later updates
leave them alone, and it may edit or delete them.
A piece that builds on one being turned off is named too, as in
`template:off rust_tasks machete doc_tests rustdoc`; otherwise copier's
validator names the rule, and nothing changes.

`template:on` adds the pieces to the list the template's questions put them
in, and runs `copier update --vcs-ref=:current:`.
A file the repository kept comes back with inline conflict markers between
its copy and the template's; the task fails and `git diff --check` lists them.

## Releases

Tags are annotated, move by patch only from `v0.0.1`, sit on a merged `main`
commit whose CI passed, and never move.
Pin the commit a tag names, with the tag as a comment.

## Checks

`mise run verify` runs every check CI runs:

| Task | Checks |
|:--|:--|
| `lint:workflows` | `actionlint` over the workflows |
| `check:pins` | Every `uses:` names a full commit SHA with a version comment |
| `check:catalog` | `tasks/rust.toml` equals its source, ctl-core v0.6.28's catalog, apart from `format`, the `test` command without `--lib`, the added `doc` and `check:docs`, and the `check:versions` guard; the catalog names no toolchain version |
| `check:docs-probes` | The catalog's `check:docs` fails each probe crate that breaks the docs standard and passes each that keeps it; only `cargo metadata --no-deps` runs, so nothing compiles |
