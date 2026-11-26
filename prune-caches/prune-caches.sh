#!/usr/bin/env bash
# Deletes every cache entry of each prefix in PREFIXES on the run's ref, except
# the newest. gh lists at most 100 entries for each prefix.
set -euo pipefail

# Deletes the entries of prefix $1 but the newest.
prune() {
  gh cache list --repo "$GITHUB_REPOSITORY" --ref "$GITHUB_REF" --key "$1" \
    --limit 100 --json id,createdAt --jq 'sort_by(.createdAt) | reverse | .[1:][].id' |
    while IFS= read -r id; do
      gh cache delete "$id" --repo "$GITHUB_REPOSITORY"
    done
}

read -ra keys <<<"$PREFIXES"
if [ "${#keys[@]}" -eq 0 ]; then
  echo "::error::prune-caches: the prefixes input is empty"
  exit 1
fi
for key in "${keys[@]}"; do
  prune "$key"
done
