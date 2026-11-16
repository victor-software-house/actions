# Homebrew tap CI

`.github/workflows/homebrew-tap-ci.yml` checks a Homebrew tap repository behind one `Style` job.
It runs `brew style` and `brew readall` over the tap.
It runs no `brew audit --online`, because a private tap's homepages answer 404.

## Caller

A tap's `ci.yml` calls the workflow by commit:

```yaml
jobs:
  style:
    permissions:
      contents: read
    uses: victor-software-house/actions/.github/workflows/homebrew-tap-ci.yml@<commit> # main, <date>
```

The job reads the tap's commit with the workflow token, so the caller grants `contents: read` and nothing more.
The workflow takes no secrets.

## Inputs

| Input | Default | Use |
|:--|:--|:--|
| `runner` | `ubuntu-26.04` | The final runner label of the job |
| `timeout-minutes` | `5` | Cancels a hung job |

## Job

| Step | Runs |
|:--|:--|
| `Set up Homebrew` | `Homebrew/actions/setup-homebrew`, pinned by commit |
| `Style` | `brew style` over the tap |
| `Read every formula and cask` | `brew readall` over the tap |

The setup action fetches the tap's commit itself, replaces the workspace with it and registers the tap.
So the job has no checkout step.
The action's `token` input is the workflow token, which lets it fetch a private tap.

The steps pass the tap to brew by the action's `tap-name` output.
That is the owner and repository without the `homebrew-` prefix, in lower case.

## Not yet checked

`brew readall` on a Linux runner has not been checked against casks that depend on macOS.
The first tap pull request that calls this workflow will show whether it reads them.
