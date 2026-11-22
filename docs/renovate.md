# Renovate

`.github/workflows/renovate.yml` runs [Renovate](https://docs.renovatebot.com/) over the active repositories of one visibility.
It opens draft pull requests and keeps them up to date.
It never merges, and never turns on auto-merge.

## Caller

The caller runs weekly and by hand.
A manual run is a dry run unless its `dry-run` input is off:

```yaml
on:
  schedule:
    - cron: "0 9 * * 1"
  workflow_dispatch:
    inputs:
      dry-run:
        type: boolean
        default: true

concurrency:
  group: renovate-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  renovate:
    uses: victor-software-house/actions/.github/workflows/renovate.yml@<commit> # main, <date>
    permissions:
      contents: read
      id-token: write
    with:
      mise-version: 2026.11.10
      visibility: public
      dry-run: ${{ inputs.dry-run || false }}
    secrets:
      RENOVATE_APP_PRIVATE_KEY: ${{ secrets.RENOVATE_APP_PRIVATE_KEY }}
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_KEY: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
```

## Scope

The Scope job lists the owner's repositories of the given visibility that are not archived, forks or mirrors.
It leaves out each repository whose `mise.toml` names a forkctl manifest, because a downstream follows its upstream's dependencies.

It then ranks the rest by their real commits on the default branch in the last 30 days:

- A real commit is not a merge, and its author is a GitHub account that is not a bot.
- Its headline is not automated work: state mirrors, template updates, releases, organization-wide CI changes or dependency bumps.
  `renovate/repositories.jq` lists the patterns.
- The query returns at most 100 commits per repository.
  A busier repository gets an estimate: its commit count times the share of real commits among those 100.

A repository needs `min-commits` real commits.
With `limit` above 0, only that many of the most active repositories run.

## Jobs

Each repository in scope gets its own job, so a slow repository reaches the 15-minute ubuntu-slim limit alone.
At most 20 jobs run at once, because they share one App installation's API rate limit.

Every job checks out only `renovate/` from this repository, at the commit the caller pinned.
`renovate/mise.toml` installs Renovate with bun from `package.json` and `bun.lock`, and the tools Renovate calls to refresh lockfiles.
`package.json` overrides `@yarnpkg/libzip` to 3.2.1, its newest release with npm provenance, so the locked install verifies.
Nix flake inputs are off, because the runner has no nix.

## Token

- The workflow mints installation tokens from a GitHub App.
  Its client ID is the variable `RENOVATE_APP_CLIENT_ID`, and its key is the secret `RENOVATE_APP_PRIVATE_KEY`.
- The Scope job's token reads repository contents across the owner.
- In a public run, each Renovate job's token reaches only the repository it updates.
  Lookups of private sources then fail, so a public run leaves Copier templates to each repository's daily Template check.
- In a private run, each Renovate job's token reaches every repository, for private sources such as the Copier templates.

## Caches

- The Scope job saves the mise tools and bun's packages; the Renovate jobs only restore them.
- Each repository keeps Renovate's repository cache, so a run reuses the dependency list of an unchanged default branch.
  A dry run does not save it.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `visibility` | required | `public` or `private`: the repositories to update |
| `min-commits` | `2` | The fewest real commits in 30 days that put a repository in scope |
| `limit` | `0` | The most repositories to update, most active first; `0` updates every one in scope |
| `exclude` | empty | Repository names to leave out, one per line |
| `dry-run` | `false` | Report what Renovate would change, and write nothing |
| `runner` | `ubuntu-slim` | The final runner label for every job |
