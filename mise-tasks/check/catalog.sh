#!/usr/bin/env bash
#MISE description="tasks/rust.toml equals its source apart from format, test, test:doc and its target directory, doc, check:docs, and the check:versions and semver guards, and names no toolchain"
# The Rust catalog is ctl-core v0.6.28's tasks/rust.toml. Every task keeps its
# source field for field, except these: format reads RUSTFMT_TOOLCHAIN in
# place of a pinned nightly; test drops --lib, which fails a crate with no
# library; test and test:doc add --no-fail-fast, so a run reports every
# failing test binary; test:doc builds in target/doctest, apart from test; doc and check:docs are new, and check:docs-probes tests the latter; check:versions fails when VERCTL_CONFIG names no
# file; and semver fails when the release config is missing. The source's verify stays with each repository, which composes its
# own.
set -euo pipefail
source_url=https://raw.githubusercontent.com/victor-software-house/ctl-core/4d5a85ce1cfe933e35eac4dccdfba67ae541f468/tasks/rust.toml
catalog=tasks/rust.toml
src=$(mktemp)
trap 'rm -f "$src"' EXIT
curl -fsSL "$source_url" -o "$src"
expect() {
  actual=$(yq -p toml -o json -r "$1" "$catalog")
  if [ "$actual" != "$2" ]; then
    printf '%s is %s, expected %s\n' "$1" "$actual" "$2" >&2
    exit 1
  fi
}
diff <(yq -p toml -o json 'del(.verify, .format, .test.run, .["test:doc"].run, .["check:versions"].run, .semver.run) | sort_keys(.)' "$src") <(yq -p toml -o json 'del(.format, .doc, .["check:docs"], .test.run, .["test:doc"].run, .["test:doc"].env, .["check:versions"].run, .semver.run) | sort_keys(.)' "$catalog")
expect '.format.run' 'cargo ${RUSTFMT_TOOLCHAIN:-} fmt --all -- --check'
expect '.test.run' 'cargo test --locked --workspace --all-features --tests --no-fail-fast'
expect '.["test:doc"].run' 'cargo test --locked --workspace --doc --all-features --no-fail-fast'
expect '.["test:doc"].env.CARGO_TARGET_DIR' 'target/doctest'
expect '.doc.run' 'cargo +${RUST_NIGHTLY} doc --no-deps --all-features --locked'
expect '.doc.env.RUSTDOCFLAGS' '--cfg docsrs -D warnings'
expect '.doc.env.CARGO_TARGET_DIR' 'target/rustdoc'
versions_guard='if [ -n "${VERCTL_CONFIG:-}" ] && [ ! -f "$VERCTL_CONFIG" ]; then
  echo "VERCTL_CONFIG=$VERCTL_CONFIG names no file" >&2
  exit 1
fi
'
expect '.["check:versions"].run' "$versions_guard$(yq -p toml -o json -r '.["check:versions"].run' "$src")"
semver_guard='config="${VERCTL_CONFIG:-.ctl/ver.yaml}"
if [ ! -f "$config" ]; then
  echo "no $config: semver runs verctl'"'"'s ver task, which needs the release config" >&2
  exit 1
fi
'
expect '.semver.run' "$semver_guard$(yq -p toml -o json -r '.semver.run' "$src")"
# The including repository pins every toolchain, so no line outside a comment
# names a dated nightly or a Rust version.
if grep -nvE '^[[:space:]]*#' "$catalog" | grep -E 'nightly-[0-9]|\+[0-9]+\.[0-9]+'; then
  echo "$catalog names a toolchain version" >&2
  exit 1
fi
