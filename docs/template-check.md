# Template check

`.github/workflows/template-check.yml` runs `template:check` from the [template catalog](../tasks/README.md#template-catalog).
It fails when the newest tag of the repository's Copier template would change the repository.

## Caller

The caller runs on pull requests, merge queue entries and daily.
It passes the release mirror's address and CI key for the [mise action](../mise/README.md), and the template-reader App's private key:

```yaml
on:
  pull_request:
  merge_group:
  schedule:
    - cron: "17 9 * * *"

jobs:
  template:
    uses: victor-software-house/actions/.github/workflows/template-check.yml@<commit> # main, <date>
    permissions:
      contents: read
      id-token: write
      issues: write
    with:
      mise-version: 2026.11.6
    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_KEY: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
      TEMPLATES_APP_PRIVATE_KEY: ${{ secrets.TEMPLATES_APP_PRIVATE_KEY }}
```

## Failures

- Only an update pull request, one that changes `.copier-answers.yml`, fails when the newest tag would change the repository.
- Every other pull request passes with a notice, so a new tag fails no unrelated pull request.
- A merge queue entry skips the check, which its pull request already ran.
  The skipped job reports success, so a ruleset that requires it lets the entry land.
- A push to the default branch runs nothing.

## The daily issue

The scheduled run opens an issue titled "Template update available".
Below the repository root, the title adds " in <directory>".
The issue lists the files the newest tag changes, and later runs update it.
It closes once the repository is on a tag that leaves nothing to update.
A repository with issues turned off gets the notice only.

## Token

- The workflow mints a read-only token for the template repository from a GitHub App.
- The App's client ID is the organization variable `TEMPLATES_APP_CLIENT_ID`.
  Its key is the organization secret `TEMPLATES_APP_PRIVATE_KEY`.
- Only the step that runs `template:check` gets the token.
- A pull request from a fork gets no secrets, so the check skips it.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory the template renders into |
| `runner` | `ubuntu-latest` | The final runner label for the check and its path filter |
| `paths` | empty | The files the template renders, one glob per line, relative to `working-directory` |

With `paths`, a pull request that changes none of those files skips the check:

- A `Changes` job on a light runner diffs the merge commit against its base with git's glob pathspecs.
  There `*` stays within one directory and `**` crosses them.
- The skipped `Template` job still reports, so a branch rule that requires `template / Template` passes.
- Pushes and scheduled runs always check.
- Without `paths`, every pull request checks.
