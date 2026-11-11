# Secrets scan

`.github/workflows/secrets.yml` runs gitleaks over a repository's commits.
The caller runs it on pull requests and daily:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  schedule:
    - cron: "47 9 * * *"

jobs:
  secrets:
    uses: victor-software-house/actions/.github/workflows/secrets.yml@<commit> # main, <date>
    permissions:
      contents: read
      id-token: write
    with:
      mise-version: 2026.10.25    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_PASSWORD: ${{ secrets.RELEASE_MIRROR_CI_PASSWORD }}
```

- A pull request scans only its own commits, from its base to its head.
- A scheduled or dispatched run scans the whole history.
  The pre-push hook scans only the commits it pushes, so the full scan runs here once a day.
- The job installs gitleaks from the caller's `mise.dev.toml`, with `MISE_ENV=dev,hooks`.
  The mirror secrets let the [mise action](../mise/README.md) download it through the release mirror.
- The install sets `MISE_LOCKED=1`, so mise takes the download URL and checksum from the caller's `mise.dev.lock` and writes no lock entries.
  A gitleaks entry missing for the platform of the `runner` input fails the job instead of slowing it.
  The default runner is linux-x64; a caller that picks a runner of another platform runs `mise lock --platform <os>-<arch>` for it.
  `MISE_NO_HOOKS=1` skips the caller's `[hooks]`, such as `lefthook install`.
- It runs the caller's `hooks:secrets:history` task, which passes its arguments to `gitleaks git`.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the caller's `mise.toml` |
| `runner` | `ubuntu-latest` | The final runner label for the scan |
