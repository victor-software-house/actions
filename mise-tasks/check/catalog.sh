#!/usr/bin/env bash
#MISE description="tasks/rust.toml equals its source apart from format, test, doc, and the check:versions guard, and names no toolchain"
# The Rust catalog is ctl-core v0.6.28's tasks/rust.toml. Every task keeps its
# source field for field, except these: format reads RUSTFMT_TOOLCHAIN in
# place of a pinned nightly; test drops --lib, which fails a crate with no
# library; doc is new; and check:versions fails when VERCTL_CONFIG names no
# file. The source's verify stays with each repository, which composes its
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
diff <(yq -p toml -o json 'del(.verify, .format, .test.run, .["check:versions"].run) | sort_keys(.)' "$src") <(yq -p toml -o json 'del(.format, .doc, .test.run, .["check:versions"].run) | sort_keys(.)' "$catalog")
expect '.format.run' 'cargo ${RUSTFMT_TOOLCHAIN:-} fmt --all -- --check'
expect '.test.run' 'cargo test --locked --workspace --all-features --tests'
expect '.doc.run' 'cargo +${RUST_NIGHTLY} doc --no-deps --all-features --locked'
expect '.doc.env.RUSTDOCFLAGS' '--cfg docsrs -D warnings'
expect '.doc.env.CARGO_TARGET_DIR' 'target/rustdoc'
versions_guard='if [ -n "${VERCTL_CONFIG:-}" ] && [ ! -f "$VERCTL_CONFIG" ]; then
  echo "VERCTL_CONFIG=$VERCTL_CONFIG names no file" >&2
  exit 1
fi
'
expect '.["check:versions"].run' "$versions_guard$(yq -p toml -o json -r '.["check:versions"].run' "$src")"
# The including repository pins every toolchain, so no line outside a comment
# names a dated nightly or a Rust version.
if grep -nvE '^[[:space:]]*#' "$catalog" | grep -E 'nightly-[0-9]|\+[0-9]+\.[0-9]+'; then
  echo "$catalog names a toolchain version" >&2
  exit 1
fi
