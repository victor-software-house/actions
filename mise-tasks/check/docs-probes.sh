#!/usr/bin/env bash
#MISE description="The catalog's check:docs fails each probe crate that breaks the docs standard and passes each that keeps it"
# Each probe is a scratch git repository with one crate and a copy of
# tasks/rust.toml, which it includes by path and tracks, so check:docs also
# searches the catalog itself. Only cargo metadata --no-deps runs, so nothing
# compiles; the Rust toolchain in mise.toml is here for that alone.
set -euo pipefail

catalog="$PWD/tasks/rust.toml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export MISE_TRUSTED_CONFIG_PATHS="$work"

meta_msg='✘ [package.metadata.docs.rs] needs'
cfg_msg='✘ no #![cfg_attr(docsrs, feature(doc_cfg))]'
lint_msg='✘ clippy::missing_{errors,panics}_doc and the pedantic group'

std_meta='[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["--cap-lints", "warn"]'
std_lints='[lints.clippy]
pedantic = { level = "deny", priority = -1 }'
std_lib='//! A probe crate.
#![cfg_attr(docsrs, feature(doc_cfg))]'

# Starts a probe repository named $1 and prints its path.
repo() {
  local dir="$work/$1"
  mkdir -p "$dir"
  cp "$catalog" "$dir/rust.toml"
  printf '[task_config]\nincludes = ["rust.toml"]\n' >"$dir/mise.toml"
  printf '%s\n' "$dir"
}

# Writes the crate at $1. The variables package, features, lints, meta, and
# lib fill Cargo.toml and src/lib.rs; an empty lib writes a binary instead.
crate() {
  local dir=$1
  mkdir -p "$dir/src"
  printf '[package]\nname = "%s"\nversion = "0.0.1"\nedition = "2024"\n%s\n\n[features]\n%s\n\n%s\n\n%s\n' \
    "$(basename "$dir")" "$package" "$features" "$lints" "$meta" >"$dir/Cargo.toml"
  if [ -n "$lib" ]; then
    printf '%s\n' "$lib" >"$dir/src/lib.rs"
  else
    printf 'fn main() {}\n' >"$dir/src/main.rs"
  fi
}

# Resets the crate variables to a crate set as the standard says.
standard() {
  package=''
  features='extra = []'
  lints=$std_lints
  meta=$std_meta
  lib=$std_lib
}

# Runs check:docs in the repository at $1 and prints its output.
run() {
  (
    cd "$1" || exit 1
    git init -q || exit 1
    git add -A || exit 1
    cargo generate-lockfile --offline -q || exit 1
    mise run check:docs 2>&1
  )
}

failed=0

# $1 names the probe, $2 is its repository, and $3 is the line check:docs
# must print as it fails.
fails() {
  local out
  if out=$(run "$2"); then
    printf '✘ %s passed check:docs:\n%s\n' "$1" "$out"
    failed=1
  elif ! grep -qF -- "$3" <<<"$out"; then
    printf '✘ %s failed without %s:\n%s\n' "$1" "$3" "$out"
    failed=1
  else
    printf '✔ %s fails\n' "$1"
  fi
}

# $1 names the probe and $2 is its repository.
passes() {
  local out
  if out=$(run "$2"); then
    printf '✔ %s passes\n' "$1"
  else
    printf '✘ %s failed check:docs:\n%s\n' "$1" "$out"
    failed=1
  fi
}

# Probes that check one crate with one change from the standard. $1 names
# the probe; the caller sets the crate variables after standard.
one() {
  local dir
  dir=$(repo "$1")
  crate "$dir"
  printf '%s\n' "$dir"
}

standard
passes 'a crate set as the standard says' "$(one standard)"

standard; meta=''
fails 'no docs.rs metadata' "$(one no-metadata)" "$meta_msg"

standard; meta='[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["-D", "warnings"]'
fails 'metadata with -D warnings' "$(one deny-warnings)" "$meta_msg"

standard; lib='//! A probe crate.'
fails 'features without the doc_cfg attribute' "$(one no-doc-cfg)" "$cfg_msg"

standard; package='publish = false'; meta=''; lib='//! A probe crate.'
passes 'a publish = false package' "$(one unpublished)"

standard; features=''; meta=''; lib=''
passes 'a binary-only package' "$(one binary)"

standard; lints="$std_lints
missing_docs_in_private_items = \"allow\""
passes 'missing_docs_in_private_items allowed' "$(one private-items)"

standard; lints='[lints.clippy]
pedantic = "warn"'
passes 'pedantic at warn' "$(one pedantic-warn)"

standard; lib="$std_lib
#![expect(clippy::missing_errors_doc, reason = \"probe\")]"
fails 'a crate-wide expect of missing_errors_doc' "$(one expect-errors)" "$lint_msg"

standard; lib="$std_lib
#![expect(clippy :: missing_errors_doc, reason = \"probe\")]"
fails 'a spaced lint path' "$(one spaced-path)" "$lint_msg"

standard; lib="$std_lib
#![expect(
    clippy::pedantic,
    reason = \"a reason long enough that rustfmt wraps the attribute\"
)]"
fails 'a wrapped expect of the pedantic group' "$(one wrapped-pedantic)" "$lint_msg"

standard; lib="$std_lib
#![deny(clippy::pedantic)]"
fails 'a deny of the pedantic group' "$(one deny-pedantic)" "$lint_msg"

# Each TOML form of a missing_errors_doc or missing_panics_doc allow.
key=0
for form in \
  'missing_errors_doc = "allow"' \
  '"missing_errors_doc" = "allow"' \
  "'missing_panics_doc' = \"allow\"" \
  '    missing_errors_doc = "allow"' \
  'missing_errors_doc = { level = "allow", priority = 1 }' \
  'missing_errors_doc.level = "allow"' \
  'missing-panics-doc = "allow"'; do
  key=$((key + 1))
  standard; lints="$std_lints
$form"
  fails "the key form $form" "$(one "key-$key")" "$lint_msg"
done

standard; lints="$std_lints

[lints.clippy.missing_errors_doc]
level = \"allow\""
fails 'a missing_errors_doc table header' "$(one key-header)" "$lint_msg"

standard; lints='[lints]
clippy.pedantic = { level = "deny", priority = -1 }
clippy.missing_errors_doc = "allow"'
fails 'a dotted missing_errors_doc key' "$(one key-dotted)" "$lint_msg"

# Each TOML form of a pedantic allow, and a pedantic table header.
key=0
for form in \
  'pedantic = "allow"' \
  '"pedantic" = "allow"' \
  'pedantic = { level = "allow", priority = -1 }' \
  'pedantic.level = "allow"'; do
  key=$((key + 1))
  standard; lints="[lints.clippy]
$form"
  fails "the pedantic form $form" "$(one "pedantic-$key")" "$lint_msg"
done

standard; lints='[lints]
clippy.pedantic = "allow"'
fails 'a dotted pedantic allow' "$(one pedantic-dotted)" "$lint_msg"

standard; lints='[lints.clippy.pedantic]
level = "deny"
priority = -1'
fails 'a pedantic table header' "$(one pedantic-header)" "$lint_msg"

# Allows outside Cargo.toml: rustflags, a split rustflags array, and a file
# task's RUSTFLAGS.
standard; dir=$(one rustflags)
mkdir -p "$dir/.cargo"
printf '[build]\nrustflags = ["-A", "clippy::missing_errors_doc"]\n' >"$dir/.cargo/config.toml"
fails 'a rustflags allow' "$dir" "$lint_msg"

standard; dir=$(one rustflags-hyphen)
mkdir -p "$dir/.cargo"
printf '[build]\nrustflags = ["-A", "clippy::missing-errors-doc"]\n' >"$dir/.cargo/config.toml"
fails 'a hyphenated rustflags allow' "$dir" "$lint_msg"

standard; dir=$(one rustflags-split)
mkdir -p "$dir/.cargo"
printf '[build]\nrustflags = [\n  "-A",\n  "clippy::pedantic",\n]\n' >"$dir/.cargo/config.toml"
fails 'a split rustflags array' "$dir" "$lint_msg"

standard; dir=$(one file-task)
mkdir -p "$dir/mise-tasks"
printf '#!/usr/bin/env bash\nRUSTFLAGS="-A clippy::missing_panics_doc" cargo clippy\n' >"$dir/mise-tasks/lint.sh"
fails "a file task's RUSTFLAGS allow" "$dir" "$lint_msg"

standard; dir=$(one file-task-bare)
mkdir -p "$dir/mise-tasks/check"
printf '#!/usr/bin/env bash\nRUSTFLAGS="-A clippy::missing_errors_doc" cargo clippy\n' >"$dir/mise-tasks/check/lints"
fails "an extensionless file task's RUSTFLAGS allow" "$dir" "$lint_msg"

# Workspace probes: an allow in the workspace lints, and an implicit feature.
dir=$(repo workspace-allow)
printf '[workspace]\nmembers = ["probe"]\nresolver = "3"\n\n[workspace.lints.clippy]\npedantic = { level = "deny", priority = -1 }\nmissing_errors_doc = "allow"\n' >"$dir/Cargo.toml"
standard; lints='[lints]
workspace = true'
crate "$dir/probe"
fails 'a workspace missing_errors_doc allow' "$dir" "$lint_msg"

dir=$(repo implicit-feature)
printf '[workspace]\nmembers = ["probe", "helper"]\nresolver = "3"\n' >"$dir/Cargo.toml"
standard; package='publish = false'; features=''; meta=''; lib='//! A helper crate.'
crate "$dir/helper"
standard; features=''; lib='//! A probe crate.'
lints="$std_lints

[dependencies]
helper = { path = \"../helper\", optional = true }"
crate "$dir/probe"
fails 'an implicit feature without the doc_cfg attribute' "$dir" "$cfg_msg"

exit "$failed"
