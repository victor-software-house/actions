# A workflow every rule accepts, and helpers that feed it to a rule the way
# conftest's ignore parser does: one entry per line.
package workflow_fixtures

import rego.v1

workflow := `name: CI
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  merge_group:
permissions:
  contents: read
concurrency:
  group: ci-${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}
  cancel-in-progress: true
jobs:
  changes:
    if: ${{ !github.event.pull_request.draft }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
  build:
    needs: changes
    runs-on: nscloud-ubuntu-24.04-amd64-2x4
    permissions:
      contents: write
    steps:
      - uses: ./.github/actions/setup
  verify:
    if: ${{ !github.event.pull_request.draft }}
    uses: org/actions/.github/workflows/rust-ci.yml@0123456789abcdef0123456789abcdef01234567 # main, 2026-11-02
    with:
      light-runner: nscloud-ubuntu-24.04-amd64-2x4
      build-runner: '["nscloud-ubuntu-24.04-amd64-4x8"]'`

lines(text) := [{"Original": line} | some line in split(text, "\n")]

# The workflow with one substring replaced.
edited(old, new) := lines(replace(workflow, old, new)) if contains(workflow, old)

file := {"name": "ci.yml", "dir": ".github/workflows"}

labels := {"labels": ["nscloud-ubuntu-24.04-amd64-2x4", "nscloud-ubuntu-24.04-amd64-4x8"]}
