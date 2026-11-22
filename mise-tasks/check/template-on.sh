#!/usr/bin/env bash
#MISE description="template:on passes each --data answer to copier update and rejects a bad one"
# Runs the task through mise, so mise's own quoting of the --data values is
# tested. The task runs against a local template and a recording uvx, and the
# lock step finds nothing to lock under a stub mise. The task's tools are left
# out, so nothing installs.
set -euo pipefail
catalog="$PWD/tasks/template.toml"
mise=$(command -v mise)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

mkdir "$work/template" "$work/bin" "$work/repo"
cat >"$work/template/mise.toml" <<'EOF'
[tools]
"pypi:copier" = "9.99.0"
EOF
cat >"$work/template/copier.yml" <<'EOF'
pieces:
  choices:
    Deny: deny
    XCFramework:
      value: go_xcframework
pieces_extra:
  choices:
    Workflow lint: lint_workflows
EOF
git -C "$work/template" init -q
git -C "$work/template" add .
git -C "$work/template" commit -q -m template
commit=$(git -C "$work/template" rev-parse HEAD)

cat >"$work/repo/.copier-answers.yml" <<EOF
_commit: $commit
_src_path: file://$work/template
pieces:
  - deny
pieces_extra:
  - lint_workflows
EOF
git -C "$work/repo" init -q
git -C "$work/repo" add .
git -C "$work/repo" commit -q -m answers
yq -p toml -o toml '{"tasks": {"template:on": (.["template:on"] | del(.tools))}}' "$catalog" >"$work/repo/mise.toml"

# uvx records its arguments, one per line. mise lists no tool to lock.
cat >"$work/bin/uvx" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$UVX_ARGS"
EOF
cat >"$work/bin/mise" <<'EOF'
#!/bin/sh
echo '[]'
EOF
chmod +x "$work/bin/uvx" "$work/bin/mise"
# A nested mise drops the tool paths the outer one added, so yq is linked in.
ln -s "$(command -v yq)" "$work/bin/yq"
export UVX_ARGS="$work/uvx.args"

# run <argument>...: mise run template:on in the scratch repository.
run() {
  rm -f "$UVX_ARGS"
  (cd "$work/repo" && env -u MISE_ENV PATH="$work/bin:$PATH" MISE_TRUSTED_CONFIG_PATHS="$work/repo" "$mise" run template:on "$@") 2>"$work/stderr"
}
fail() {
  printf '✘ %s\n' "$1" >&2
  exit 1
}

# Each answer is its own --data argument, after pieces and pieces_extra, with
# its spaces and shell characters kept and nothing run.
run go_xcframework --data xcframework_module=Foo --data 'repository=owner/name with space' --data 'note=$(touch ran)' || fail "template:on failed with --data: $(cat "$work/stderr")"
expected=$(printf '%s\n' \
  copier@9.99.0 update --quiet --defaults --vcs-ref=:current: \
  --data 'pieces=["deny","go_xcframework"]' \
  --data 'pieces_extra=["lint_workflows"]' \
  --data xcframework_module=Foo \
  --data 'repository=owner/name with space' \
  --data 'note=$(touch ran)')
[ "$(cat "$UVX_ARGS")" = "$expected" ] || fail "copier got other arguments than expected: $(cat "$UVX_ARGS")"
[ ! -e "$work/repo/ran" ] || fail "a --data value ran as a command"

# With no --data, mise leaves usage_data unset and the call is what it was
# before the flag.
run go_xcframework || fail "template:on failed without --data: $(cat "$work/stderr")"
[ "$(grep -c '^--data$' "$UVX_ARGS")" -eq 2 ] || fail "copier got an extra --data: $(cat "$UVX_ARGS")"

# A value without = and the two keys the task sets are rejected before copier runs.
for bad in xcframework_module pieces=[] pieces_extra=[]; do
  if run go_xcframework --data "$bad"; then
    fail "template:on accepted --data $bad"
  fi
  [ ! -e "$UVX_ARGS" ] || fail "copier ran for --data $bad"
  grep -q '^template:on: --data ' "$work/stderr" || fail "no error for --data $bad: $(cat "$work/stderr")"
done
printf '✔ template:on passes --data and rejects a bad one\n'
