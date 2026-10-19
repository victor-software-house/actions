#!/usr/bin/env bash
#MISE description="tasks/rust.toml equals its sources apart from format, test, and doc, and names no toolchain"
# The Rust catalog started as ctl-core v0.6.20's tasks/rust.toml. Every task
# but format, test, and doc keeps its source field for field; the source's
# verify stays with each repository, which composes its own. test differs in
# its command only. check:versions came later, from ctl-core v0.6.28; it keeps
# that source's description, and its command adds a guard that fails when
# VERCTL_CONFIG names no file.
set -euo pipefail
source_url=https://raw.githubusercontent.com/victor-software-house/ctl-core/98e6717a020b44fb4ae95175991e1038d27fb4e4/tasks/rust.toml
versions_url=https://raw.githubusercontent.com/victor-software-house/ctl-core/4d5a85ce1cfe933e35eac4dccdfba67ae541f468/tasks/rust.toml
catalog=tasks/rust.toml
src=$(mktemp)
versions_src=$(mktemp)
trap 'rm -f "$src" "$versions_src"' EXIT
curl -fsSL "$source_url" -o "$src"
curl -fsSL "$versions_url" -o "$versions_src"
expect() {
  actual=$(yq -p toml -o json -r "$1" "$catalog")
  if [ "$actual" != "$2" ]; then
    printf '%s is %s, expected %s\n' "$1" "$actual" "$2" >&2
    exit 1
  fi
}
diff <(yq -p toml -o json 'del(.verify, .format, .test.run)' "$src") <(yq -p toml -o json 'del(.format, .doc, .test.run, .["check:versions"])' "$catalog")
diff <(yq -p toml -o json '.["check:versions"] | del(.run)' "$versions_src") <(yq -p toml -o json '.["check:versions"] | del(.run)' "$catalog")
versions_guard='if [ -n "${VERCTL_CONFIG:-}" ] && [ ! -f "$VERCTL_CONFIG" ]; then
  echo "VERCTL_CONFIG=$VERCTL_CONFIG names no file" >&2
  exit 1
fi
'
expect '.["check:versions"].run' "$versions_guard$(yq -p toml -o json -r '.["check:versions"].run' "$versions_src")"
expect '.format.run' 'cargo ${RUSTFMT_TOOLCHAIN:-} fmt --all -- --check'
expect '.test.run' 'cargo test --locked --all-features --tests'
expect '.doc.run' 'cargo +${RUST_NIGHTLY} doc --no-deps --all-features --locked'
expect '.doc.env.RUSTDOCFLAGS' '--cfg docsrs -D warnings'
expect '.doc.env.CARGO_TARGET_DIR' 'target/rustdoc'
# The including repository pins every toolchain, so no line outside a comment
# names a dated nightly or a Rust version.
if grep -nvE '^[[:space:]]*#' "$catalog" | grep -E 'nightly-[0-9]|\+[0-9]+\.[0-9]+'; then
  echo "$catalog names a toolchain version" >&2
  exit 1
fi
