#!/usr/bin/env bash
#MISE description="Shared workflows consume final infrastructure inputs without runtime visibility policy"
set -euo pipefail
workflows=(.github/workflows/rust-ci.yml .github/workflows/template-check.yml .github/workflows/secrets.yml)
if grep -nE 'github\.event\.repository\.private|nscloud-(ubuntu|macos)|namespace-(4x8|8x16|16x32)|cheapest|needs\.runner' "${workflows[@]}"; then
  echo 'shared workflows must consume final caller configuration' >&2
  exit 1
fi
yq -e '.jobs.runner == null' .github/workflows/rust-ci.yml >/dev/null
yq -e '.on.workflow_call.inputs."build-runner".type == "string" and .on.workflow_call.inputs.runner == null' .github/workflows/rust-ci.yml >/dev/null
for file in .github/workflows/template-check.yml .github/workflows/secrets.yml; do
  yq -e '.on.workflow_call.inputs.runner.type == "string"' "$file" >/dev/null
done
yq -e '.on.workflow_call.inputs.light-runner.default == "ubuntu-latest"' .github/workflows/rust-ci.yml >/dev/null

# Execute the guard the workflow actually ships, not a second implementation.
guard=$(yq -r '.jobs.build.steps[0].run' .github/workflows/rust-ci.yml)
VALID_CONFIG=true CAPACITY_LABEL=cache-size-50gb CAPACITY_GB=50 bash -c "$guard"
mkdir -p target
if VALID_CONFIG=false CAPACITY_LABEL=cache-size-50gb CAPACITY_GB=50 bash -c "$guard" >target/cache-guard.log 2>&1; then
  echo "cache guard accepted invalid final label configuration" >&2
  exit 1
fi
for size in '' 50.5 invalid; do
  if VALID_CONFIG=true CAPACITY_LABEL="cache-size-${size}gb" CAPACITY_GB="$size" bash -c "$guard" >target/cache-guard.log 2>&1; then
    echo "cache guard accepted invalid capacity $size" >&2
    exit 1
  fi
done
if VALID_CONFIG=true CAPACITY_LABEL=cache-size-20gb CAPACITY_GB=50 bash -c "$guard" >target/cache-guard.log 2>&1; then
  echo "cache guard accepted mismatched final capacity" >&2
  exit 1
fi
