# Task catalogs

mise task catalogs a repository includes by commit.
An inline `[tasks.<name>]` in the repository's `mise.toml` replaces a catalog task of the same name.

## Rust catalog

`rust.toml` holds the standard Rust tasks.
Include it in `mise.toml` after `mise-tasks`, and set the toolchains it reads:

```toml
[settings]
# mise loads git:: task includes only in experimental mode.
experimental = true

[env]
# format runs on this toolchain when set, for rustfmt's unstable options.
RUSTFMT_TOOLCHAIN = "+nightly-2026-11-01"
# doc builds on this nightly, as docs.rs does.
RUST_NIGHTLY = "nightly-2026-11-01"

[task_config]
includes = [
  "mise-tasks",
  "git::https://github.com/victor-software-house/actions.git//tasks/rust.toml?ref=<commit>",
]
```

The catalog names no toolchain version and defines no `verify`.
Each repository pins its own tools.
It composes `verify` from the tasks it runs, beside its own `check:features` and `check:repo`.

| Task | Runs |
|:--|:--|
| `format` | `cargo fmt`, on `RUSTFMT_TOOLCHAIN` when set, else on the pinned stable |
| `lint`, `test`, `test:doc` | With `--workspace`, so every member of a workspace is checked |
| `doc` | `cargo +$RUST_NIGHTLY doc --no-deps --all-features --locked`, with `RUSTDOCFLAGS="--cfg docsrs -D warnings"` |
| `check:docs` | The docs standard below, for a repository that publishes |
| `check:versions` | Fails when a manifest version changed outside a Version PR |
| `semver` | `mise run ver semver`, at the release type the pending fragments allow |
| `check:toolchain`, `deny`, `deny:advisories`, `deps` | As in ctl-core's catalog |

### Compared with ctl-core

`check:catalog` keeps `rust.toml` equal to ctl-core v0.6.28's catalog, apart from these changes:

- `format` and its `RUSTFMT_TOOLCHAIN`;
- the `test` command without `--lib`;
- the added `doc` and `check:docs`;
- the guard in `check:versions`.

### doc

A rustdoc warning fails `doc` before docs.rs sees it.
It builds every feature, even when a crate's docs.rs metadata lists fewer.
So it checks every gated item docs.rs could render.

### check:docs

`check:docs` checks what `doc` cannot see:

- Every library cargo would publish sets `rustdoc-args = ["--cap-lints", "warn"]` in `[package.metadata.docs.rs]`.
- That table chooses what docs.rs builds: `all-features = true`, or a `features` list.
  A list fits when all features would build heavy dependencies that gate no documented item.
- A library with a feature besides `default` carries `#![cfg_attr(docsrs, feature(doc_cfg))]` at its crate root.
- No tracked Rust, TOML or shell file names `clippy::missing_{errors,panics}_doc` or `clippy::pedantic`.
  Neither does any file in a mise file-task directory.
  A crate names those lints only to change their level, which the standard forbids.
- A `[lints]` key fails for either `missing_*_doc` lint at any level, and for `pedantic` at `allow`.

It runs `cargo metadata`, `jq` and `git grep`, so the repository pins `jq`.

### check:versions and semver

- `check:versions` passes with a notice when the repository has no `.ctl/ver.yaml` and `VERCTL_CONFIG` is unset.
- It fails when `VERCTL_CONFIG` names no file.
- A repository that declares releases includes verctl's `ver` task, which `check:versions` calls.
- `semver` also runs through `ver`, so a published crate includes `ver` too.
  It fails when the release config is missing.

## Template catalog

`template.toml` holds `template:check`, `template:off` and `template:on`.
Include it beside the Rust catalog:

```toml
[task_config]
includes = [
  "mise-tasks",
  "git::https://github.com/victor-software-house/actions.git//tasks/template.toml?ref=<commit>",
]
```

Copier runs through `uvx`, at the version the template pins as `"pypi:copier"` in its own `mise.toml`.
Each task declares uv and python in its `tools` table, and `mise lock` records them in the repository's lock.

### template:check

- It reads `_src_path` and `_commit` from `.copier-answers.yml`.
- It runs `copier update` to the template's newest `vX.Y.Z` tag.
- It fails when that changes any file besides the answers file.
- A newer tag that renders no change passes with a notice.
- With `TEMPLATE_DRIFT=notice`, a tag that changes files passes with a notice too.
  The update then stays in the working tree.

The [template check workflow](../docs/template-check.md) runs it in CI.

### template:off and template:on

The template answers `pieces` and `pieces_extra` list the pieces the template manages.
A plain `copier update --data` that drops a piece deletes the piece's files, edited or not.
So change the lists through these tasks:

```sh
mise run template:off deny
mise run template:on deny
```

`template:off`:

- It renders the recorded template version with and without the pieces, and takes the files that disappear.
- It runs `copier update --vcs-ref=:current:` without the pieces, with one `--exclude` per such file.
- The repository keeps its copies and owns them from then on.
  Later updates leave them alone, and the repository may edit or delete them.
- A piece that builds on one being turned off is named too, as in `template:off rust_tasks machete doc_tests rustdoc`.
  Otherwise copier's validator names the rule, and nothing changes.

`template:on`:

- It adds the pieces to the list the template's questions put them in.
- It runs `copier update --vcs-ref=:current:`.
- A file the repository kept comes back with inline conflict markers between its copy and the template's.
  The task then fails, and `git diff --check` lists them.
- A piece's tasks can declare tools the locks do not hold yet, such as Vale for `lint_prose`.
  The task locks exactly the tools `mise lock --dry-run --json` lists, for the platforms in `lockfile_platforms`.
- It locks once in the default profiles, then once per `mise.<profile>.toml` that git does not ignore, except `hooks`, `local` and `*.local`.
  So the `ci` and `release` locks get the tools too, and the pre-push lock check and a locked install pass.
