# Bun CI

`.github/workflows/bun-ci.yml` builds and tests a Bun repository with its `mise run verify`.
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
      packages: read
      pull-requests: read
    uses: victor-software-house/actions/.github/workflows/bun-ci.yml@<commit> # main, <date>
    with:
      mise-version: 2026.11.6
    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_KEY: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
```

The permissions follow [Rust CI](rust-ci.md#caller): `Changes` and `Build and test` read the pull request, `Verify` reads the run with `actions: read`, and the build job's mise action needs `id-token: write`.
The build job also reads the organization's packages, so the caller grants `packages: read`.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `mise-version` | none | The mise release the job installs |
| `working-directory` | `.` | The directory that holds `mise.toml` and `bun.lock` |
| `timeout-minutes` | `8` | The limit of the Verify step |
| `build-runner` | `["ubuntu-26.04"]` | The build job's final labels, as a JSON array |
| `light-runner` | `ubuntu-26.04` | The label of the `Changes` and `Verify` jobs, and of a documentation-only build |

## Jobs

| Job | Runner | Runs |
|:--|:--|:--|
| `Changes` | `light-runner` | On a pull request, whether it changes anything besides documentation |
| `Build and test` | `build-runner`; light for documentation-only changes | `mise run verify`, or the documentation checks |
| `Verify` | `light-runner` | Reports the build's result through [verify-jobs](../verify-jobs/README.md) |

Documentation is the root's Markdown files, `docs/` and `openspec/`.
A documentation file still counts as a build input when a TypeScript or JavaScript source names its path.
A documentation-only pull request runs whichever of `lint:md`, `lint:typos`, `lint:prose` and `specs` the repository defines.

## Dependencies

The repository's `[deps.bun]` provider runs `bun install --frozen-lockfile` before each `mise run`, so `verify` finds `node_modules` in place, and a stale `bun.lock` fails the run.
`bunfig.toml` takes the GitHub Packages token from `GITHUB_TOKEN`, which the build job sets to the job's token.

Bun's package cache, `~/.bun/install/cache`, is keyed on `bun.lock` and restored on every run.
Only a push to the default branch or a dispatch saves it, so a pull request never writes an entry another run restores.
A repository that lands through a merge queue has no push run; its daily refresh dispatches CI on the default branch.
