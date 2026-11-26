#!/usr/bin/env bash
# Posts the job's OIDC token to URL as a bearer token, with URL as the token's
# audience. The endpoint checks the token's signature, issuer, audience and
# subject, and rejects a token it has seen, so each attempt takes a new one.
# Five attempts, ten seconds apart.
set -euo pipefail

: "${URL:?post-oidc-token: the url input is empty}"
if [[ $URL != https://* ]]; then
  echo "::error::post-oidc-token: the url must start with https://, so the token never travels in plain text"
  exit 1
fi
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?post-oidc-token: the job needs the permission id-token: write}"

# Prints a curl config line that sends $2 as an Authorization header of
# scheme $1. curl reads it with --config -, so no token reaches its arguments.
auth_header() {
  printf 'header = "Authorization: %s %s"\n' "$1" "$2"
}

# Makes attempt $1 and fails when it posts nothing.
attempt() {
  local response token
  # The answer is {"count":…,"value":"<JWT>"}, and a JWT has no quotes.
  if ! response=$(auth_header bearer "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" |
    curl -fsS -G --max-time 30 --config - \
      --data-urlencode "audience=$URL" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL"); then
    echo "Attempt $1: no OIDC token"
    return 1
  fi
  if [[ ! $response =~ \"value\":\"([^\"]+)\" ]]; then
    echo "Attempt $1: no token in the answer"
    return 1
  fi
  token=${BASH_REMATCH[1]}
  echo "::add-mask::$token"
  if ! auth_header Bearer "$token" | curl -fsS -X POST --max-time 60 --config - "$URL"; then
    echo "Attempt $1: the endpoint refused or did not answer"
    return 1
  fi
}

for n in 1 2 3 4 5; do
  if attempt "$n"; then
    exit 0
  fi
  if [ "$n" -lt 5 ]; then
    sleep 10
  fi
done
exit 1
