#!/usr/bin/env bash
#MISE description="template:on passes each --data answer to copier update and rejects a bad one"
# Runs the task's script against a local template and a recording uvx, with
# the arguments mise gives it: usage_piece and usage_data, each value quoted
# for the shell. The lock step finds nothing to lock under the stub mise.
set -euo pipefail
catalog="$PWD/tasks/template.toml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

script="$work/template-on.sh"
yq -p toml -o json -r '.["template:on"].run' "$catalog" >"$script"

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
export UVX_ARGS="$work/uvx.args"

# run <piece> <usage_data>: the task's script as mise runs it.
run() {
  rm -f "$UVX_ARGS"
  (cd "$work/repo" && PATH="$work/bin:$PATH" usage_piece="$1" usage_data="$2" bash "$script") 2>"$work/stderr"
}
fail() {
  printf '✘ %s\n' "$1" >&2
  exit 1
}

# Each answer is its own --data argument, after pieces and pieces_extra, with
# its spaces kept.
run go_xcframework "'xcframework_module=Foo' 'repository=owner/name with space'" || fail "template:on failed with --data: $(cat "$work/stderr")"
expected=$(printf '%s\n' \
  copier@9.99.0 update --quiet --defaults --vcs-ref=:current: \
  --data 'pieces=["deny","go_xcframework"]' \
  --data 'pieces_extra=["lint_workflows"]' \
  --data xcframework_module=Foo \
  --data 'repository=owner/name with space')
[ "$(cat "$UVX_ARGS")" = "$expected" ] || fail "copier got other arguments than expected: $(cat "$UVX_ARGS")"

# With no --data the call is what it was before the flag.
run go_xcframework "" || fail "template:on failed without --data: $(cat "$work/stderr")"
[ "$(grep -c '^--data$' "$UVX_ARGS")" -eq 2 ] || fail "copier got an extra --data: $(cat "$UVX_ARGS")"

# A value without = and the two keys the task sets are rejected before copier runs.
for bad in "'xcframework_module'" "'pieces=[]'" "'pieces_extra=[]'" "'xcframework_module=Foo' 'nokey'"; do
  if run go_xcframework "$bad"; then
    fail "template:on accepted --data $bad"
  fi
  [ ! -e "$UVX_ARGS" ] || fail "copier ran for --data $bad"
  grep -q '^template:on: --data ' "$work/stderr" || fail "no error for --data $bad: $(cat "$work/stderr")"
done
printf '✔ template:on passes --data and rejects a bad one\n'
