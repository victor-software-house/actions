#!/usr/bin/env bash
#MISE description="Every uses: names a full commit SHA with a version comment"
# A tag or branch can move, so every reference here, and every reference a
# consumer makes into this repository, names the commit. A local path in
# this repository's own workflows, such as the CI's test of ./mise, runs from
# the same checkout and takes no ref; in a published action it would resolve
# against the caller's checkout, so it stays refused there.
set -euo pipefail
bad=$(git ls-files -z '*.yml' '*.yaml' | xargs -0 grep -nE '^[[:space:]]*(-[[:space:]]+)?uses:' |
  grep -vE 'uses:[[:space:]]+[^@[:space:]]+@[0-9a-f]{40}[[:space:]]+#[[:space:]]*[^[:space:]]' |
  grep -vE '^\.github/workflows/[^:]+:[0-9]+:[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]+\./' || true)
if [ -n "$bad" ]; then
  printf 'not pinned by commit with a version comment:\n%s\n' "$bad" >&2
  exit 1
fi
