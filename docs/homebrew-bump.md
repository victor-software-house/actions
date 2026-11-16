# Homebrew bump

`.github/workflows/homebrew-bump.yml` points one cask of a tap at a release of its app.
It sets the cask's `version` and the sha256 of the release asset, then opens and squash-merges a pull request.

## Caller

A tap's workflow calls it from a release dispatch, a schedule or a manual run, and passes the release's tag:

```yaml
jobs:
  bump:
    permissions:
      contents: read
    uses: victor-software-house/actions/.github/workflows/homebrew-bump.yml@<commit> # main, <date>
    with:
      cask: example
      source-repository: victor-software-house/example
      tag: ${{ github.event.client_payload.tag }}
      asset: Example.pkg
    secrets:
      CHANGESET_VERSION_APP_CLIENT_ID: ${{ secrets.CHANGESET_VERSION_APP_CLIENT_ID }}
      CHANGESET_VERSION_APP_PRIVATE_KEY: ${{ secrets.CHANGESET_VERSION_APP_PRIVATE_KEY }}
```

The caller contract:

- The Version Packages App is installed on the tap and on the source repository.
  The workflow mints one token for both, with `contents: write` and `pull-requests: write`.
- The source repository has the tap's owner, because the token is requested for repository names under that owner.
- The caller passes both secrets.
- The caller's own concurrency group, if it has one, is not named `homebrew-bump-<cask>`, which the workflow holds.

The tap's default branch takes changes only through a pull request, and the workflow token may not open one.
So the bump opens and merges its pull request as the App.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `cask` | required | The cask's token; the file is `Casks/<cask>.rb` |
| `source-repository` | required | The release's repository, as `owner/name` |
| `tag` | required | The release tag to bump to |
| `tag-pattern` | `^v([0-9]+\.[0-9]+\.[0-9]+)$` | A bash extended regular expression the tag must match; its first capture group is the version |
| `asset` | required | The release asset's file name |
| `runner` | `ubuntu-26.04` | The final runner label of the job |

## Secrets

| Secret | Use |
|:--|:--|
| `CHANGESET_VERSION_APP_CLIENT_ID` | The Version Packages App's client ID; required |
| `CHANGESET_VERSION_APP_PRIVATE_KEY` | The Version Packages App's private key; required |

## Steps

1. The job checks that `cask` is a cask token, that `source-repository` is `owner/name`, and that the tag matches `tag-pattern`.
   The pattern's first capture group must hold a version.
2. It mints the App token and checks out the tap with it.
3. It stops with success when the cask already has the version.
4. It downloads the asset with `gh` and fails unless its sha256 matches the digest the release lists for it.
5. It rewrites the cask's `version` and `sha256` lines and checks that both changed.
6. It commits on `bump/<cask>-<version>` as `github-actions[bot]` and pushes the branch.
7. It opens a pull request whose body links the release, and squash-merges it, deleting the branch.

One bump per cask runs at a time, and a queued one waits instead of cancelling the running one.
Every input reaches the shell through `env:`.
