#!/usr/bin/env bash
# Publishes each directory under $ROOT as a one-layer OCI artifact on GHCR when
# its content differs from the `latest` tag. The README beside this file
# describes the inputs, which arrive as environment variables.
set -euo pipefail
shopt -s inherit_errexit nullglob

# tar sorts names by the locale's collation, so fix it for a stable archive.
export LC_ALL=C

namespace=${OWNER,,}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

crane() {
  mise x "aqua:google/go-containerregistry@${CRANE_VERSION}" -- crane "$@"
}

login() {
  printf '%s' "$TOKEN" | crane auth login ghcr.io -u "$GITHUB_ACTOR" --password-stdin
}

# The same files always give the same bytes, so an unchanged group has the
# same digest as the last publish.
archive() {
  local name=$1 out=$2
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$ROOT" -cf - "$name" |
    gzip -n -9 >"$out"
}

sha256() {
  local sum
  sum=$(sha256sum "$1")
  printf 'sha256:%s\n' "${sum%% *}"
}

# Prints the digest of the first layer of the ref's latest tag, and nothing
# when the package or the tag is not published yet. GHCR answers DENIED for a
# package that does not exist, so DENIED counts as not published too. A real
# authentication failure then fails at the push, with crane's own error.
latest_layer() {
  local ref=$1 manifest
  if ! manifest=$(crane manifest "$ref:latest" 2>"$work/error"); then
    if grep -q -e NAME_UNKNOWN -e MANIFEST_UNKNOWN -e DENIED "$work/error"; then
      return 0
    fi
    cat "$work/error" >&2
    return 1
  fi
  jq -r '.layers[0].digest' <<<"$manifest"
}

publish() {
  local ref=$1 archive=$2
  crane append -f "$archive" -t "$ref:$GITHUB_SHA" >&2
  crane mutate --label "org.opencontainers.image.source=$SOURCE" "$ref:$GITHUB_SHA" >&2
  crane tag "$ref:$GITHUB_SHA" latest >&2
}

# Prints the group's entry of the groups output.
process_group() {
  local name=$1 ref archive_path layer digest changed
  ref="ghcr.io/$namespace/$PREFIX$name"
  archive_path="$work/$name.tar.gz"
  archive "$name" "$archive_path"
  layer=$(latest_layer "$ref")
  if [[ $layer == "$(sha256 "$archive_path")" ]]; then
    changed=false
    digest=$(crane digest "$ref:latest")
  else
    changed=true
    publish "$ref" "$archive_path"
    digest=$(crane digest "$ref:$GITHUB_SHA")
  fi
  jq -nc --arg package "$ref" --arg digest "$digest" --argjson changed "$changed" \
    '{package: $package, digest: $digest, changed: $changed}'
}

# A package name is lowercase, so a group name must be too. Checking every
# name first publishes nothing when one is bad.
check_names() {
  local pattern='^[a-z0-9]+([._-][a-z0-9]+)*$' bad='' name
  for name in "$@"; do
    if [[ ! $name =~ $pattern ]]; then
      bad+="$name, "
    fi
  done
  if [[ -n $bad ]]; then
    echo "::error::A group name must match $pattern; rename: ${bad%, }"
    return 1
  fi
}

summary_row() {
  jq -r --arg name "$1" '"| \($name) | `\(.package)` | `\(.digest)` | \(.changed) |"' <<<"$2"
}

main() {
  local dirs=("$ROOT"/*/) dir name names=() entry groups='{}'
  if ((${#dirs[@]} == 0)); then
    echo "::error::$ROOT has no group directory"
    return 1
  fi
  for dir in "${dirs[@]}"; do
    name=${dir%/}
    names+=("${name##*/}")
  done
  check_names "${names[@]}"
  login
  printf '| Group | Package | Digest | Changed |\n| :-- | :-- | :-- | :-- |\n' >>"$GITHUB_STEP_SUMMARY"
  for name in "${names[@]}"; do
    entry=$(process_group "$name")
    groups=$(jq -c --arg name "$name" --argjson entry "$entry" '. + {($name): $entry}' <<<"$groups")
    summary_row "$name" "$entry" >>"$GITHUB_STEP_SUMMARY"
  done
  echo "groups=$groups" >>"$GITHUB_OUTPUT"
}

main
