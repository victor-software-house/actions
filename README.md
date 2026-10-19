# actions

Shared CI logic and mise task catalogs, called by commit from the repositories
that use them.
Logic that is identical everywhere lives here once; each repository carries
only the line that pins it.

## Contents

| Path | Holds |
|:--|:--|
| `tasks/rust.toml` | The standard Rust tasks: `check:toolchain`, `format`, `lint`, `test`, `test:doc`, `deny`, `deny:advisories`, `deps`, `semver`, and `doc` |
| `.github/workflows/rust-ci.yml` | The reusable Rust CI workflow: one `Verify` job that runs `mise run verify`, then the network checks |

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
      mise-version: 2026.10.9
```

The job runs on `ubuntu-latest` for a public repository and on the Namespace
runner for a private one, read from the calling repository's visibility.
It checks out the repository with its submodules, installs the locked tools
with mise, restores mbx's compiled objects, and runs `mise run verify` with
`MISE_ENV=ci` and git's first branch set to `main`.
The mise install cache is on for GitHub-hosted runners and off on Namespace,
where a restored cache lacks rustup's components.
A step the workflow does not run, such as a release build, goes in a job of
the calling workflow beside the call.

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the crate's `mise.toml` |
| `advisories` | `true` | Runs `mise run deny:advisories` after `verify` |
| `semver` | `false` | Runs `mise run semver` and `cargo package`, for a published crate |
| `timeout-minutes` | `8` | Cancels a hung `Verify` job |

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
| `check:catalog` | `tasks/rust.toml` equals its source, ctl-core v0.6.20's catalog, apart from `format` and the added `doc`, and names no toolchain version |
