#!/bin/sh
#MISE description="The workflow policy passes its tests, and the pins rule runs over this repository's workflows"
set -eu
conftest verify --data policy/defaults.yaml
# rust-ci.yml has lines that end in a backslash, which conftest's ignore
# parser cannot read, so this run proves the rules take the text from data.
# GitHub runs .yml and .yaml workflows alike; -z hands xargs each path whole,
# and -r runs nothing when there are none.
texts=$(git rev-parse --git-path workflow-texts.yaml)
sh policy/texts.sh >"$texts"
git ls-files -z ':(glob).github/workflows/*.yml' ':(glob).github/workflows/*.yaml' |
  xargs -0 -r conftest test -p policy --namespace workflow_pins --data policy/defaults.yaml --data "$texts"
