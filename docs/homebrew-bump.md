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
  The workflow mints a token for the tap with `contents: write` and `pull-requests: write`, and one for the source repository with `contents: read`.
- The source repository has the tap's owner, because the tokens are requested for repository names under that owner.
- The tap allows auto-merge in its settings, because the workflow enables it on the pull request.
- The tap turns on automatically deleting head branches, because the CLI does not delete the branch of an auto-merged pull request.
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
2. It mints two App tokens and checks out the tap with the first.
   The tap token has `contents: write` and `pull-requests: write` on the tap alone, and serves the checkout, the push and the pull request.
   The source token has `contents: read` on the source repository alone, and serves only the release reads.
3. It stops with success when the cask already has the version.
4. It compares versions.
   It goes on only when its version is newer than the cask's version on the default branch.
   It must also be newer than the version of every other open bump pull request of the cask.
   Otherwise it writes a `::notice::` that names the newer version, changes nothing and stops with success.
   So a late run of an old tag is not an error, and a version equal to an open bump's leaves that pull request alone.
5. It downloads the asset with `gh` and fails unless its sha256 matches the digest the release lists for it.
6. It rewrites the cask's `version` and `sha256` lines and checks that both changed.
7. It commits on `bump/<cask>-<version>` as `github-actions[bot]` and pushes the branch.
8. It opens a pull request whose body links the release.
   It closes every other open bump pull request of the cask, which step 4 found older, with a comment that names the new tag, and deletes their branches.
   It then enables auto-merge with squash.
   The merge waits for the required checks, so the step does not fail while they run.

Every input reaches the shell through `env:`.

## Version order

Versions compare with `sort -V` over the first capture group of `tag-pattern`.
It orders `vX.Y.Z` tags correctly.

A caller whose versions `sort -V` orders wrongly, such as `1.2-3` against `1.2`, must dispatch them in order.
The workflow cannot tell a newer one from an older one.

An open bump of the same cask matches by its branch prefix `bump/<cask>-` and its title prefix `<cask>: bump to `.
So a cask whose token starts with another's is not mistaken for it.

## Concurrency

One bump per cask runs at a time, and a running one is never cancelled.
Only the newest queued run is kept, and a newer one cancels the older pending run.
That is fine, because the newest tag wins.
Auto-merge returns before the merge, so a run frees the group while its pull request is still open.
The next run then finds that pull request, and closes it when its own version is newer.
That keeps two pull requests that edit the same lines from standing open.
