#!/usr/bin/env bash
#MISE description="mise renders every task script in the shared catalogs"
# mise renders a task's script with Tera before it runs it, so `{#`, `{{` or
# `{%` in shell code, such as ${#array[@]}, stops the task in every consumer.
# A dry run renders each script and runs nothing.
set -euo pipefail
catalogs=("$PWD"/tasks/*.toml)
# mise reports task sources by their resolved path.
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
export MISE_TRUSTED_CONFIG_PATHS="$work"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
cd "$work"
git init -q
includes=""
for catalog in "${catalogs[@]}"; do
  cp "$catalog" .
  includes+="\"$(basename "$catalog")\", "
done
printf '[task_config]\nincludes = [%s]\n' "$includes" >mise.toml
# A dry run with no arguments stops at a task's first required argument, so
# such a task runs again with a placeholder for each.
# A task whose dry run still fails, rendered or not, counts as a failure.
tasks=$(mise tasks ls --json | jq -r --arg work "$work" '.[] | select(.source | startswith($work)) | .name')
if [ -z "$tasks" ]; then
  echo "✘ found no tasks from tasks/*.toml" >&2
  exit 1
fi
failed=0
while IFS= read -r task; do
  args=()
  while true; do
    status=0
    out=$(mise run --dry-run --no-deps "$task" "${args[@]}" 2>&1) || status=$?
    if [ "$status" -eq 0 ] || ! grep -q 'Missing required arg' <<<"$out" || [ "${#args[@]}" -ge 5 ]; then
      break
    fi
    args+=(placeholder)
  done
  if [ "$status" -ne 0 ]; then
    printf '✘ %s does not render:\n%s\n' "$task" "$out"
    failed=1
  else
    printf '✔ %s renders\n' "$task"
  fi
done <<<"$tasks"
exit "$failed"
