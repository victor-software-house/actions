# actions

Shared CI logic and mise task catalogs, called by commit from the repositories
that use them.
Logic that is identical everywhere lives here once; each repository carries
only the line that pins it.

## Contents

| Path | Holds |
|:--|:--|
| `tasks/rust.toml` | The standard Rust tasks: `check:toolchain`, `format`, `lint`, `test`, `test:doc`, `deny`, `deny:advisories`, `deps`, `check:versions`, `semver`, `doc`, and `check:docs` |
| `.github/workflows/rust-ci.yml` | The reusable Rust CI workflow: a build job that runs `mise run verify`, static and publish checks beside it, and one `Verify` job that reports them all |
| `tasks/template.toml` | `template:check`, which fails when the newest tag of the repository's Copier template would change it, and `template:off` and `template:on`, which turn template pieces off and on |
| `.github/workflows/template-check.yml` | The reusable drift check: a `Template` job that runs `template:check` with a token that reads the template, skipped for a pull request that touches none of the caller's `paths` |
| `.github/workflows/secrets.yml` | The reusable credential scan: a `Secrets` job that runs gitleaks over a pull request's own commits, or over the whole history on a schedule |
| `macos-signing/` | The signing actions: `macos-signing` loads the CI Developer ID identities and the notary key from 1Password into a temporary keychain, `macos-signing/delete` removes them |

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

The caller supplies final build labels as JSON in `build-runner`, final read-only labels in `read-only-runner`, and a concrete `light-runner` label.
Repository visibility, provider selection and machine sizes are resolved when the caller is rendered, not by this workflow.
There is no runner-resolution job or abstract runner mode.
Public generated callers carry only their selected public configuration.
It checks out the repository with its submodules, installs the locked tools
with mise, restores mbx's compiled objects, and runs `mise run verify` with
`MISE_ENV=ci` and git's first branch set to `main`.
A cache step that fails, such as a save refused because the commit's key is already reserved on a re-run, does not fail the job: the result comes from the build and tests.
The caller explicitly selects persistent-volume caching with `cache-volume`.
A volume caller must supply its concrete read-only safety label and an explicit positive `cache-size` matching its runner labels.
The render fragment derives the size label and trim limit from one value; render tests check they match.
The execution guard refuses missing safety configuration without resolving provider policy.
On Namespace the job runs with a cache volume tagged `rust-<repository>`,
sized by `cache-size`, and keeps mise's installs, rustup's toolchains, Cargo's
home, `target/`, and mbx's store on it; the job commits the volume when it
exits cleanly, and the next job forks the newest commit.
Only a merge queue run, or a push, dispatch or schedule run on the default
branch, commits the volume, so only reviewed code writes the toolchains and
the store that every later build runs; a pull request or a run on any other
branch reads the volume and never commits it.
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
A `Changes` job on a light runner reads the changed paths with
[dorny/paths-filter](https://github.com/dorny/paths-filter).
Documentation is the root's Markdown files, `docs/`, and `openspec/`,
except a file a Rust source names by its repository path, alone or at the
end of a relative path, as a test or an `include_str!` that reads it does.
For such a pull request, the build job runs on a light runner, installs the tools
without Rust, and runs whichever of `lint:md`, `lint:typos`, and `specs` the
repository defines.
With `semver`, every pull request builds: `cargo package` ships documentation
files, and the `Package` step checks it.
The `Verify` check reports a result either way.

The jobs, which run in parallel after `Changes`:

| Job | Runner | Runs |
|:--|:--|:--|
| `Build and test` | final `build-runner` or `read-only-runner` labels; light for documentation-only changes | `mise run verify` |
| `Static checks` | `light-runner` | configured static checks, then advisories |
| `Publish checks` | `read-only-runner` | with `semver`: API and package checks |
| `Verify` | `light-runner` | fails when a required job failed or was cancelled |

The caller chooses every label at apply time. Runtime choices only reflect
the event or changed files, such as read-only cache safety for pull requests.

A ruleset requires only `Verify` (`verify / Verify` from a caller job named
`verify`), so the jobs behind it can change without a ruleset change, and an
upstream failure cannot skip a required check into green.
Only the build job writes the build cache.
Parallel jobs that commit one Namespace cache tag overwrite each other
([Cache Volumes](https://namespace.so/docs/architecture/storage/cache-volumes):
last write wins, no merge step), so `Publish checks` mounts it read-only, and
on a GitHub-hosted runner saves under its own key suffix.
A push to the default branch always builds, so the mbx cache saved from it
stays current.

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the crate's `mise.toml` |
| `advisories` | `true` | Runs `mise run deny:advisories` in `Static checks` |
| `semver` | `false` | Runs `mise run semver` and `cargo package`, for a published crate |
| `timeout-minutes` | `8` | Cancels a hung `Verify`, `Semver` or `Package` step |
| `build-runner` | `["ubuntu-latest"]` | JSON array of final build labels |
| `read-only-runner` | `["ubuntu-latest"]` | JSON array of final labels for builds that cannot commit cache state |
| `light-runner` | `ubuntu-latest` | Final label for lightweight jobs |
| `cache-volume` | `false` | Use the supplied persistent build cache volume |
| `read-only-label` | empty | Concrete safety label required when a persistent volume is selected |
| `cache-size` | `0` | Explicit volume size in GB, matching the rendered runner labels |

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
a light runner diffs the merge commit against its base with git's glob
pathspecs, where `*` stays within one directory and `**` crosses them.
The skipped `Template` job still reports, so a branch rule that requires
`template / Template` passes.
Pushes and scheduled runs always check.
Without `paths`, every pull request checks.

## Scan for credentials

The caller runs on pull requests and daily, and calls the scan by commit:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  schedule:
    - cron: "47 9 * * *"

jobs:
  secrets:
    uses: victor-software-house/actions/.github/workflows/secrets.yml@<commit> # <tag>
    with:
      mise-version: 2026.10.17
```

A pull request scans only its own commits, from its base to its head; a
scheduled or dispatched run scans the whole history.
The repository's pre-push hook scans only the commits it pushes, so the
whole history is scanned here once a day, not on every push.
The job installs gitleaks from the caller's `mise.dev.toml` and runs the
caller's `hooks:secrets:history` task, which passes its arguments to
`gitleaks git`, with `MISE_ENV=dev,hooks`.

## Sign and notarize on macOS

The CI Developer ID identities and the App Store Connect notary key live only
in 1Password, in the Environment `VSH CI macOS signing`.
A release job fetches them through
[1Password Credential Broker](https://www.1password.dev/brokered-access/github-actions.md),
which checks the job's GitHub OIDC token against the repository's connection
(repository, `release` environment, branch) before it releases the values.
No repository holds a copy, and rotating a credential means changing it in
that one Environment.

The signing job names the `release` environment, may request an OIDC token,
and calls the action by commit before it signs, with the cleanup last:

```yaml
jobs:
  sign:
    runs-on: macos-latest
    environment: release
    permissions:
      contents: write
      id-token: write # the token 1Password checks
    steps:
      - uses: victor-software-house/actions/macos-signing@<commit> # <tag>
        with:
          workload-id: ${{ vars.OP_WORKLOAD_ID }}
          environment-id: ${{ vars.OP_ENVIRONMENT_ID }}
          integration-key: ${{ secrets.OP_INTEGRATION_KEY }}
          installer: true # only for productbuild
      # codesign --sign "Developer ID Application" …, then
      # xcrun notarytool submit … --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
      - if: always()
        uses: victor-software-house/actions/macos-signing/delete@<commit> # <tag>
```

The Environment holds `MACOS_APP_P12_BASE64`, `MACOS_APP_P12_PASSWORD`,
`MACOS_INSTALLER_P12_BASE64`, `MACOS_INSTALLER_P12_PASSWORD`,
`NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`, each on one
line, the files base64-encoded.
The action loads the Environment's values as step outputs, so no later step
sees them in its environment.
It imports the Developer ID Application identity, and the Installer identity
when `installer` is `true`, into a temporary keychain under `RUNNER_TEMP`
that becomes the only keychain searched: `codesign` takes the first matching
identity in the search list, whatever `--keychain` names.
It writes the notary key to a private file and sets `NOTARY_KEY_PATH`,
`NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` for the next steps.
`macos-signing/delete` restores the login keychain and deletes the temporary
one and the key file.

| Input | Default | Effect |
|:--|:--|:--|
| `workload-id` | required | The repository's 1Password workload, its `OP_WORKLOAD_ID` variable |
| `environment-id` | required | The 1Password Environment that holds the signing set, `OP_ENVIRONMENT_ID` |
| `integration-key` | required | The organization secret `OP_INTEGRATION_KEY`, an encryption key useless without a matching OIDC token |
| `installer` | `false` | Also imports the Developer ID Installer identity |

Build in a job without the `release` environment and sign the artifact in
another, so no dependency code runs while the identity is unlocked.
A pull request from a fork gets no secret, so it cannot reach the action.

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
