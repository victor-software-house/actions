#!/usr/bin/env bash
# Writes build=false to GITHUB_OUTPUT when every changed path is documentation
# that no source reads, and build=true otherwise.
# action.yml lists the documentation paths and sets ALL, DOCS and DOCS_FILES
# from the path filter, and GO and SWIFT from the inputs.
set -euo pipefail

# Fails unless each named input is true or false.
check_flags() {
  local name value
  for name in "$@"; do
    value=${!name}
    case $value in
      true | false) ;;
      *)
        echo "::error::build-scope: the ${name,,} input is '$value', and must be true or false"
        exit 1
        ;;
    esac
  done
}

# A //go:embed line names files with no quotes, as a directory or a glob,
# relative to its own package, and a package embeds only files in its own
# directory or below. So a Go source with such a line, in the file's directory
# or a directory above it, may embed the file.
embeds() {
  local dir=$1
  while :; do
    if git grep -qE '^[[:space:]]*//go:embed' -- ":(glob)${dir:+$dir/}*.go"; then
      return 0
    fi
    if [ -z "$dir" ]; then
      return 1
    fi
    case $dir in
      */*) dir=${dir%/*} ;;
      *) dir='' ;;
    esac
  done
}

# Whether a source reads the documentation file $1.
# A Go source names the file by its path from the root, as a test run there
# does, or by a relative path that ends in it.
# A Swift source spells its path from the root, or a relative path that climbs
# to the root and ends in it.
read_by_source() {
  local file=$1 dir
  case $file in
    */*) dir=${file%/*} ;;
    *) dir='' ;;
  esac
  if [ "$GO" = true ] && { git grep -qF -e "$file" -- '*.go' || embeds "$dir"; }; then
    return 0
  fi
  if [ "$SWIFT" = true ] && git grep -qF -e "/$file\"" -e "\"$file\"" -e "\"./$file\"" -- '*.swift'; then
    return 0
  fi
  return 1
}

# Prints true when the build reads a changed path, else false.
decide() {
  local file
  if [ "$ALL" != "$DOCS" ]; then
    echo true
    return
  fi
  if [ "$GO" = true ] || [ "$SWIFT" = true ]; then
    while IFS= read -r file; do
      if read_by_source "$file"; then
        echo "A source reads $file, so the build reads it." >&2
        echo true
        return
      fi
    done < <(jq -r '.[]' <<<"$DOCS_FILES")
  fi
  echo false
}

check_flags GO SWIFT
build=$(decide)
echo "build=$build" >>"$GITHUB_OUTPUT"
