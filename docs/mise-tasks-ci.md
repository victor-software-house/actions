# Mise tasks CI

`.github/workflows/mise-tasks-ci.yml` checks a repository of shared mise task groups behind one `Verify` job.
Where the caller sets `publish`, a `Publish` job then publishes each changed group as a one-layer OCI artifact on GHCR.

## Caller

A repository's `ci.yml` calls the workflow by commit, with the mise release it pins:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  merge_group:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.workflow }}-${{ github.event_name }}-${{ github.event.pull_request.number || github.ref_name }}
  cancel-in-progress: ${{ github.event_name != 'push' }}

jobs:
  verify:
    permissions:
      contents: read
      id-token: write
      packages: write
    uses: victor-software-house/actions/.github/workflows/mise-tasks-ci.yml@<commit> # main, <date>
    with:
      mise-version: 2026.11.6
      publish: ${{ github.event_name == 'push' }}
    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_KEY: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
```

Both jobs run the mise action, which needs `id-token: write` for the release mirror.
`Publish` writes the packages, so the caller grants `packages: write`.
GitHub refuses to start a called workflow when a job's permissions exceed the caller's, so the caller grants all three on every event.

The concurrency group never cancels a run on a push, so a publish is not cut short.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `mise-version` | none | The mise release the jobs install |
| `runner` | `ubuntu-26.04` | The final runner label of both jobs |
| `timeout-minutes` | `10` | Cancels a hung job |
| `publish` | `false` | Runs the `Publish` job after `Verify` passes |

## Jobs

| Job | Runs |
|:--|:--|
| `Verify` | `mise run verify`, skipped on a draft pull request |
| `Publish` | [publish-task-groups](../publish-task-groups/README.md), after `Verify` passes and only when `publish` is set |

The workflow does not check the event or the branch.
The caller decides when to publish, so the packages are the default branch's groups and never a pull request's.

## Using a group

The action reports each group's digest in its `groups` output and in the job summary.
A repository includes a group by that digest:

```toml
[task_config]
includes = ["oci::ghcr.io/<owner>/tasks-<group>@sha256:<digest>"]
```
