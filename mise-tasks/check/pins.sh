#!/usr/bin/env bash
#MISE description="Every uses: names a full commit SHA with a version comment"
# A tag or branch can move, so every reference here, and every reference a
# consumer makes into this repository, names the commit.
set -euo pipefail
bad=$(git ls-files -z '*.yml' '*.yaml' | xargs -0 grep -nE '^[[:space:]]*(-[[:space:]]+)?uses:' |
  grep -vE 'uses:[[:space:]]+[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]*[^[:space:]]' || true)
if [ -n "$bad" ]; then
  printf 'not pinned by commit with a version comment:\n%s\n' "$bad" >&2
  exit 1
fi
