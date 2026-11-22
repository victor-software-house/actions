#!/usr/bin/env bash
#MISE description="Prints the job matrix: the active repos of one visibility"
#MISE tools = { gh = "2.105.0", jq = "1.8.2" }
# Reads RENOVATE_VISIBILITY (public or private), RENOVATE_MIN_COMMITS,
# RENOVATE_LIMIT and RENOVATE_EXCLUDE, and counts commits from the last 30
# days. GH_TOKEN must read the owner's repositories of that visibility.
set -euo pipefail

since=$(jq --null-input --raw-output 'now - 30 * 86400 | todate')

gh api graphql --paginate --slurp -F query=@repositories.graphql \
  -F owner="${GITHUB_REPOSITORY_OWNER:?}" \
  -F privacy="${RENOVATE_VISIBILITY^^}" -F since="$since" |
  jq --raw-output --from-file repositories.jq \
    --argjson min "${RENOVATE_MIN_COMMITS:?}" \
    --argjson limit "${RENOVATE_LIMIT:?}" \
    --arg exclude "${RENOVATE_EXCLUDE:-}" |
  jq --raw-input --slurp --compact-output --from-file matrix.jq
