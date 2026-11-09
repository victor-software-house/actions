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
    with:
      mise-version: 2026.10.25
```

- A pull request scans only its own commits, from its base to its head.
- A scheduled or dispatched run scans the whole history.
  The pre-push hook scans only the commits it pushes, so the full scan runs here once a day.
- The job installs gitleaks from the caller's `mise.dev.toml`, with `MISE_ENV=dev,hooks`.
- It runs the caller's `hooks:secrets:history` task, which passes its arguments to `gitleaks git`.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the caller's `mise.toml` |
| `runner` | `ubuntu-latest` | The final runner label for the scan |
