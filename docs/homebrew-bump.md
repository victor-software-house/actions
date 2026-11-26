# Homebrew bump

`.github/workflows/homebrew-bump.yml` points one cask or formula of a tap at a release.
It sets the file's `version` and the sha256 of each release asset, then opens and squash-merges a pull request.

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
- The caller's own concurrency group, if it has one, is not named `homebrew-bump-<key>`, which the workflow holds.

The tap's default branch takes changes only through a pull request, and the workflow token may not open one.
So the bump opens and merges its pull request as the App.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `cask` | `""` | The cask's token; the file is `Casks/<cask>.rb` |
| `formula` | `""` | The formula's name; the file is `Formula/<formula>.rb` |
| `source-repository` | required | The release's repository, as `owner/name` |
| `tag` | required | The release tag to bump to |
| `tag-pattern` | `^v([0-9]+\.[0-9]+\.[0-9]+)$` | A bash extended regular expression the tag must match; its first capture group is the version |
| `asset` | required | The release asset's file name; a formula takes one name per line |
| `runner` | `ubuntu-26.04` | The final runner label of the job |

## Secrets

| Secret | Use |
|:--|:--|
| `CHANGESET_VERSION_APP_CLIENT_ID` | The Version Packages App's client ID; required |
| `CHANGESET_VERSION_APP_PRIVATE_KEY` | The Version Packages App's private key; required |

## Steps

1. The job checks that exactly one of `cask` and `formula` is set, that it is a cask token or formula name, that `source-repository` is `owner/name`, and that the tag matches `tag-pattern`.
   A cask takes one asset name.
   The pattern's first capture group must hold a version.
2. It mints two App tokens and checks out the tap with the first.
   The tap token has `contents: write` and `pull-requests: write` on the tap alone, and serves the checkout, the push and the pull request.
   The source token has `contents: read` on the source repository alone, and serves only the release reads.
3. It reads the file's version at the default branch's tip, whatever ref the caller's run checked out.
   It stops with success when the file already has the version.
4. It compares versions.
   It goes on only when its version is newer than the file's version on the default branch.
   It must also be newer than the version of every other open bump pull request of the same cask or formula.
   Otherwise it writes a `::notice::` that names the newer version, changes nothing and stops with success.
   So a late run of an old tag is not an error.
   An open pull request at the run's own version is its earlier attempt's, and step 9 reuses it.
5. It downloads each asset with `gh` and fails unless its sha256 matches the digest the release lists for it.
6. It closes the open bump pull requests that step 4 found older, with a comment that names the new tag, and deletes their branches.
   A pull request that merged meanwhile fails to close, and the run leaves it with a notice.
7. It fetches the default branch again and reads the file's version at its tip.
   It stops with a notice when the file is already at or past this version, as when an older bump merged since step 3.
8. It commits on `bump/<key>-<version>`, built on that tip, as `github-actions[bot]`.
   It rewrites the `version` line, then the sha256 of each asset, checks that each changed, and pushes the branch.
   A cask has one `sha256` line.
   A formula names each asset in a `url` line that interpolates `#{version}`, and the first `sha256` line after that url, before any other url, is the asset's.
9. It opens a pull request whose body links the release, unless the branch already has an open one.
   It then enables auto-merge with squash.
   The merge waits for the required checks, so the step does not fail while they run.
   A rerun after a partial failure repairs it this way.

Every input reaches the shell through `env:`.

## Formulae

A formula that installs release binaries names one asset per platform:

```ruby
class Example < Formula
  version "0.0.1"

  on_macos do
    url "https://github.com/victor-software-house/example/releases/download/v#{version}/example_#{version}_macos_arm64.tar.gz"
    sha256 "…"
  end

  on_linux do
    url "https://github.com/victor-software-house/example/releases/download/v#{version}/example_#{version}_linux_x64.tar.gz"
    sha256 "…"
  end
end
```

Its caller passes both asset names, one per line, and the workflow sets the sha256 under each url.

## Version order

Versions compare with `sort -V` over the first capture group of `tag-pattern`.
It orders `vX.Y.Z` tags correctly.

A caller whose versions `sort -V` orders wrongly, such as `1.2-3` against `1.2`, must dispatch them in order.
The workflow cannot tell a newer one from an older one.

An open bump of the same cask or formula matches by its branch prefix `bump/<key>-` and its title prefix `<name>: bump to `.
The key of a cask is its token, and the key of a formula is `formula-<name>`, so a cask and a formula of the same name never match each other.
A cask token may not start with `formula-`, so no cask shares a formula's key.
A name that starts with another's is not mistaken for it either.

## Concurrency

One bump per cask or formula runs at a time, and a running one is never cancelled.
Only the newest queued run is kept, and a newer one cancels the older pending run.
That is fine, because the newest tag wins.
Auto-merge returns before the merge, so a run frees the group while its pull request is still open.
The next run then finds that pull request, and closes it when its own version is newer.
That keeps two pull requests that edit the same lines from standing open.
Building the commit on the default branch's current tip covers an older pull request that merged while the run was working.
