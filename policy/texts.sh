#!/bin/sh
# Writes the workflows' text, as YAML data for conftest --data, to stdout:
# workflow_texts.<file name> holds each named file whole. The pins rule reads
# comments from it, because conftest parses each workflow as YAML, which drops
# them. Each file goes into a block scalar with an explicit indentation, so
# no line, whatever it holds, ends it early.
set -eu
printf 'workflow_texts:\n'
for file in "$@"; do
  name=$(basename "$file" | sed 's/[\\"]/\\&/g')
  printf '  "%s": |2-\n' "$name"
  # awk ends every line with a newline, the last one too, so a file without
  # a final newline cannot pull the next file's header into its block.
  awk '{ print "    " $0 }' "$file"
done
