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
| `update:own` | `cargo update` of the locked crates that `CARGO_TRUSTED_OWNERS` publish, past the publish-age cooldown; see below |
| `check:versions` | Fails when a manifest version changed outside a Version PR |
| `check:registry` | `mise run ver check registry`: each crate's crates.io state, and the release freeze |
| `semver` | `mise run ver semver`, at the release type the pending fragments allow |
| `check:toolchain`, `deny`, `deny:advisories`, `deps` | As in ctl-core's catalog |

### Compared with ctl-core

`check:catalog` keeps `rust.toml` equal to ctl-core v0.6.28's catalog, apart from these changes:

- `format` and its `RUSTFMT_TOOLCHAIN`;
- the `test` command without `--lib`;
- the added `doc`, `check:docs`, `check:registry` and `update:own`;
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

### update:own

Rust 1.100's resolver skips a version newer than the publish-age cooldown, unless `Cargo.lock` already holds it.
The including repository sets the cooldown with `CARGO_REGISTRY_GLOBAL_MIN_PUBLISH_AGE`.
Cargo has no exemption for one crate, only for a registry.
Crates our own accounts publish are trusted, so `update:own` updates exactly those past the cooldown.

- `CARGO_TRUSTED_OWNERS` is a space-separated list of crates.io user logins.
  The task fails when it is unset or empty, and when the crates.io lookup of a listed login fails, as it does for an unknown user.
- It lists each login's crates through the crates.io API, and intersects them with the crates in `Cargo.lock` that come from crates.io, so a same-named crate from another registry stays out.
- It runs one `CARGO_RESOLVER_INCOMPATIBLE_PUBLISH_AGE=allow cargo update` for the crates in the intersection.
  Each is named as `-p <name>@<version>`, since cargo rejects a bare name that the lock holds in two versions.
- The allow setting covers the whole resolve, so a new release of an owned crate can pull a fresh crate we do not own past the cooldown.
- The task records the packages of `Cargo.lock` before and after, read from the file so a feature off by default hides none.
  Only an owned crate from crates.io may be added or change version.
- Any other change restores `Cargo.lock` and fails the task, naming those crates with their new versions.
  Wait for the cooldown, or update them deliberately with `CARGO_RESOLVER_INCOMPATIBLE_PUBLISH_AGE=allow cargo update -p <crate> --precise <version>` after review.
- On success it prints each owned crate that moved, old version to new.
- It exits 0 with a notice when no locked crate is owned by those logins.

It reads crates.io and writes `Cargo.lock`, so it belongs in no `verify` list.
Run it by hand.

### check:versions, check:registry and semver

- `check:versions` and `check:registry` pass with a notice when the repository has no `.ctl/ver.yaml` and `VERCTL_CONFIG` is unset.
- They fail when `VERCTL_CONFIG` names no file.
- `check:registry` needs verctl 0.8.6-rc.4 or later.
  On a pull request or a merge group it reads the release workflow's runs and the pull request's labels with `GITHUB_TOKEN`, so the caller grants `actions: read` and `pull-requests: read`.
- It waits up to `VERCTL_RELEASE_WAIT` for a running release, so it belongs in no `verify` list.
  The shared Rust CI runs it in its own `Release freeze` job, on every pull request and merge group.
- A repository that declares releases includes verctl's `ver` task, which `check:versions` calls.
- `semver` also runs through `ver`, so a published crate includes `ver` too.
  It fails when the release config is missing.

## Swift catalog

`swift.toml` holds the standard Swift tasks.
Include it in `mise.toml` after `mise-tasks`:

```toml
[settings]
# mise loads git:: task includes only in experimental mode.
experimental = true

[env]
# swift:docs documents these modules, space-separated.
SWIFT_DOC_TARGETS = "MyLibrary"

[task_config]
includes = [
  "mise-tasks",
  "git::https://github.com/victor-software-house/actions.git//tasks/swift.toml?ref=<commit>",
]
```

The catalog names no Swift or Xcode version and defines no `check`.
The toolchain on the `PATH` runs every task, and the including repository selects it, such as through `DEVELOPER_DIR` on macOS.
`swift format`, `docc`, symbol graph extraction and API digestion ship inside the toolchain, so the catalog installs nothing and the manifest names no plugin.

| Task | Runs |
|:--|:--|
| `swift:build` | `swift build --build-tests` |
| `swift:test` | `swift test` |
| `swift:lint` | `swift format lint --strict --parallel --recursive` over `Package.swift`, `Sources` and `Tests`, whichever exist |
| `swift:format` | `swift format format --in-place --parallel --recursive` over the same paths |
| `swift:docs` | `swift package dump-symbol-graph`, then `docc convert --warnings-as-errors` for each target in `SWIFT_DOC_TARGETS` |
| `swift:api` | `swift package diagnose-api-breaking-changes` against the newest `v<major>.<minor>.<patch>` tag |

### swift:lint and swift:format

- Each file is linted with the `.swift-format` nearest above it, so a repository relaxes a rule for `Tests/` with its own file there.
- Both fail when none of the three paths exists.

### swift:docs

- `SWIFT_DOC_TARGETS` is a space-separated list of module names.
  The task fails when it is unset or empty.
- A target's catalog is `Sources/<target>/<target>.docc` when that folder exists.
  Without one, `docc` builds from the symbol graph alone.
- It reads the symbol graph folder from the output of `swift package dump-symbol-graph`, since that folder moves with SwiftPM's build system.
- `docc` comes from `xcrun --find docc` on macOS and from the `PATH` elsewhere.
- Any `docc` warning fails the task, such as a symbol link that resolves to nothing.
- The output goes to a temporary folder that the task deletes.

### swift:api

- It picks the newest tag that matches `v<major>.<minor>.<patch>` exactly, the tags SwiftPM resolves versions from.
  With no such tag it prints a notice and passes.
- It completes a shallow clone with its tags first, because the baseline checkout needs the history.
- A breaking change fails the task unless the next release already allows it.
  A fragment that is still pending goes into the next release, so the task reads every `.changeset/*.md` tracked at `HEAD` and compares no base branch.
- A fragment allows the break when a front matter line declares a package at a level that permits it.
  Below 1.0, which is a tag with major 0, `minor` and `major` permit a break.
  From 1.0, only `major` does.
- A `VERSION` file that names a newer release also allows the break.
  This covers the commit of a merged Version PR, which removes the fragments before the tag exists.
  Below 1.0, a newer major or minor counts.
  From 1.0, only a newer major counts.
- A failure of the tool that reports no API breakage, such as a build error, fails the task, with or without a fragment.

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
mise run template:on go_xcframework --data xcframework_module=Foo --data repository=owner/name
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
- The update takes the answers the repository records, and the template's default for every other question.
  A piece whose answers have no valid default, such as `xcframework_module` for `go_xcframework`, needs `--data key=value`.
- `--data` repeats, once for each answer.
  The task passes each value to `copier update` as its own `--data` argument, after `pieces` and `pieces_extra`.
- An answer that must differ from its default takes `--data` too.
  The `repository` answer defaults to `<owner>/<folder>`, so a run from a worktree renders the worktree's folder name unless `--data repository=<owner>/<name>` sets it.
- A value without `=` fails the task, and so do the keys `pieces` and `pieces_extra`, which the task sets from its piece arguments.
  Nothing changes then.
- A file the repository kept comes back with inline conflict markers between its copy and the template's.
  The task then fails, and `git diff --check` lists them.
- A piece's tasks can declare tools the locks do not hold yet, such as Vale for `lint_prose`.
  The task locks exactly the tools `mise lock --dry-run --json` lists, for the platforms in `lockfile_platforms`.
- It locks once in the default profiles, then once per `mise.<profile>.toml` that git does not ignore, except `hooks`, `local` and `*.local`.
  So the `ci` and `release` locks get the tools too, and the pre-push lock check and a locked install pass.
