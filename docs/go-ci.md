# Go CI

`.github/workflows/go-ci.yml` builds and tests a Go module.
Its jobs report through one `Verify` job, the only check a ruleset requires.

## Caller

A repository's `ci.yml` calls the workflow by commit, with the mise release it pins:

```yaml
jobs:
  verify:
    permissions:
      actions: read
      contents: read
      id-token: write
      pull-requests: read
    uses: victor-software-house/actions/.github/workflows/go-ci.yml@<commit> # main, <date>
    with:
      mise-version: 2026.11.6
      task: go:verify
      extra-tasks: go:vuln
    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_KEY: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
```

The permissions follow [Rust CI](rust-ci.md#caller): `Changes` and `Build and test` read the pull request, `Verify` reads the run with `actions: read`, and the build job's mise action needs `id-token: write`.
The caller passes the organization secrets `RELEASE_MIRROR_URL` and `RELEASE_MIRROR_CI_KEY`, so the build downloads its tools through the release mirror.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `mise-version` | none | The mise release the job installs |
| `task` | `check` | The mise task `Build and test` runs, such as `go:verify` |
| `extra-tasks` | empty | Space-separated mise tasks that run after `task`, in order, such as `go:vuln` |
| `timeout-minutes` | `8` | The limit of the `task` step, and of the `extra-tasks` step as a whole |
| `build-runner` | `["ubuntu-26.04"]` | The build job's final labels, as a JSON array |
| `light-runner` | `ubuntu-26.04` | The label of the `Changes` and `Verify` jobs |

## Jobs

| Job | Runner | Runs |
|:--|:--|:--|
| `Changes` | `light-runner` | On a pull request, whether it changes anything besides documentation |
| `Build and test` | `build-runner` | The `task`, then each of `extra-tasks`, with `MISE_ENV=ci` |
| `Verify` | `light-runner` | Reports the build's result through [verify-jobs](../verify-jobs/README.md) |

A ruleset requires only `Verify`, as `verify / Verify` from a caller job named `verify`.
`Verify` fails when `Build and test` failed or was cancelled, and passes when it was skipped.
So the check reports on a documentation-only pull request and in a merge group.

## Documentation-only changes

Documentation is the root's Markdown files, `docs/` and `openspec/`.
A pull request that changes only documentation skips `Build and test`.
A documentation file still counts as a build input when a Go source names its path anywhere, in a string, a raw string or a `//go:embed` line.
Any other event runs the build: a merge group, a push and a dispatch have no `Changes` job, and so do a pull request whose `Changes` job failed.

## Caches

The job restores two caches before it runs the task:

- The mise tools cache, keyed on the `mise*.lock` files, which the mise action saves right after the install.
- The Go cache, one entry holding the module cache and the build cache, at the paths `go env GOMODCACHE` and `go env GOCACHE` print for the pinned Go.

The Go key is `go-<OS>-<arch>-<go version>-<hash>`:

- The Go version is `go env GOVERSION`.
- The hash covers every `go.sum`.
- A restore key without the hash lets a changed `go.sum` start from the newest entry of the same Go version.

Only a run on the default branch saves the Go cache, and only when no entry matched the key exactly.
A pull request, a merge group and a run on another branch restore it and never write.
A merge group runs on its own branch, which no pull request restores from.
A repository that lands through a merge queue has no push run, so its daily refresh dispatches CI on the default branch.

A cache step that fails does not fail the job.
The key follows `go.sum`, so the build cache keeps what the last `go.sum` change saved, and compiled packages of newer sources are not added until the next one.
