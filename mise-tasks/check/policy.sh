#!/bin/sh
#MISE description="The workflow policy passes its tests, and the pins rule runs over this repository's workflows and composite actions"
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
# Each composite action is named action.yml, and texts.sh keys a text by
# its file name, so each one gets a texts file of its own.
git ls-files -z ':(glob)**/action.yml' ':(glob)**/action.yaml' |
  xargs -0 -r -n 1 sh -c 'set -eu; { printf "workflow_texts:\n"; sh policy/texts.sh "$2"; } >"$1"
    conftest test -p policy --namespace workflow_pins --data policy/defaults.yaml --data "$1" "$2"' _ "$texts"
