#!/usr/bin/env bash
#MISE description="Shared workflows consume final infrastructure inputs without runtime visibility policy"
set -euo pipefail
workflows=(.github/workflows/rust-ci.yml .github/workflows/template-check.yml .github/workflows/secrets.yml)
if grep -nE 'github\.event\.repository\.private|nscloud-(ubuntu|macos)|namespace-(4x8|8x16|16x32)|cheapest|needs\.runner' "${workflows[@]}"; then
  echo 'shared workflows must consume final caller configuration' >&2
  exit 1
fi
yq -e '.jobs.runner == null' .github/workflows/rust-ci.yml >/dev/null
for file in "${workflows[@]}"; do
  yq -e '.on.workflow_call.inputs.runner.type == "string"' "$file" >/dev/null
done
yq -e '.on.workflow_call.inputs.light-runner.default == "ubuntu-latest"' .github/workflows/rust-ci.yml >/dev/null
