# actions

Shared CI logic and mise task catalogs, called by commit from the repositories
that use them.
Logic that is identical everywhere lives here once; each repository carries
only the line that pins it.

## Contents

| Path | Holds |
|:--|:--|
| `tasks/rust.toml` | The standard Rust tasks: `check:toolchain`, `format`, `lint`, `test`, `test:doc`, `deny`, `deny:advisories`, `deps`, `semver`, and `doc` |

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
