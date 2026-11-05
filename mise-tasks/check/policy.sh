#!/bin/sh
#MISE description="The workflow policy passes its tests, and the pins rule runs over this repository's workflows"
set -eu
conftest verify --data policy/defaults.yaml
# rust-ci.yml has lines that end in a backslash, which conftest's ignore
# parser cannot read, so this run proves the rules take the text from data.
texts=$(git rev-parse --git-path workflow-texts.yaml)
sh policy/texts.sh .github/workflows/*.yml >"$texts"
conftest test -p policy --namespace workflow_pins \
  --data policy/defaults.yaml --data "$texts" .github/workflows/*.yml
