#!/bin/sh
# Writes the text of the repository's workflows, as YAML data for conftest
# --data, to stdout; run it from the repository root. workflow_texts.<file
# name> holds each .yml or .yaml file under .github/workflows whole. The pins
# rule reads comments from it, because conftest parses each workflow as YAML,
# which drops them. Each file goes into a block scalar with an explicit
# indentation, so no line, whatever it holds, ends it early.
set -eu
if [ "$#" -eq 0 ]; then
  # The header comes once, here: xargs may split the files over several runs
  # of this script, each of which writes only entries.
  printf 'workflow_texts:\n'
  git ls-files -z ':(glob).github/workflows/*.yml' ':(glob).github/workflows/*.yaml' | xargs -0 -r sh "$0"
  exit
fi
for file in "$@"; do
  name=$(basename "$file" | sed 's/[\\"]/\\&/g')
  printf '  "%s": |2-\n' "$name"
  # awk ends every line with a newline, the last one too, so a file without
  # a final newline cannot pull the next file's header into its block.
  awk '{ print "    " $0 }' "$file"
done
