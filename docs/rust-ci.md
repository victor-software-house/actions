# Rust CI

`.github/workflows/rust-ci.yml` builds and tests a Rust repository.
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
    uses: victor-software-house/actions/.github/workflows/rust-ci.yml@<commit> # main, <date>
    with:
      mise-version: 2026.11.6
    secrets:
      RELEASE_MIRROR_URL: ${{ secrets.RELEASE_MIRROR_URL }}
      RELEASE_MIRROR_CI_PASSWORD: ${{ secrets.RELEASE_MIRROR_CI_PASSWORD }}
```

A reusable workflow gets no permission its caller withholds:

- `Changes` and `Static checks` read the pull request.
- `Verify` reads the run and its newer runs, with `actions: read`.
- The jobs that install tools ask for `id-token: write`, the mise action's fallback until it drops the OIDC exchange.

The caller passes the organization secrets `RELEASE_MIRROR_URL` and `RELEASE_MIRROR_CI_PASSWORD`, so those jobs download through the release mirror with the `ci` login.

GitHub refuses to start the workflow when the caller withholds one of them.
So a caller grants `actions: read` and `id-token: write` in the same change that moves its pin to a commit whose jobs ask for them.

With `id-token: write`, every step of those jobs can request an OIDC token for any audience.
That includes the pull request's build scripts and tests.
A branch in the same repository could grant itself that permission in its own workflow anyway, and a fork's pull request gets no token.
Keep every cloud or federation trust policy off these repositories' `pull_request` subject.

## Jobs

The jobs run in parallel after `Changes`:

| Job | Runner | Runs |
|:--|:--|:--|
| `Build and test` | `build-runner` or `read-only-runner`; light for documentation-only changes | `mise run verify` |
| `Static checks` | `light-runner` | The configured static checks, then advisories |
| `Publish checks` | `read-only-runner` | With `semver`: the API and package checks |
| `Verify` | `light-runner` | Reports the result of the jobs above |

`Verify` fails when a required job failed or was cancelled.
It passes a cancelled run only when a newer run replaced it, for the same event, branch and head commit.

A ruleset requires only `Verify`, as `verify / Verify` from a caller job named `verify`.
So the jobs behind it can change without a ruleset change.
An upstream failure cannot skip a required check into green.

A step the workflow does not run, such as a release build, goes in a job of the calling workflow beside the call.

## Runners

The caller passes final labels, chosen when the caller is rendered from the template:

- `build-runner` and `read-only-runner`: JSON arrays of labels;
- `light-runner`: one label.

The workflow resolves no visibility, provider or machine size itself.
Public callers carry only their own public configuration.
Choices at run time follow only the event or the changed files, such as read-only cache safety for pull requests.

## The build

`Build and test` checks out the repository with its submodules.
It installs the locked tools with the [mise action](../mise/README.md) and restores mbx's compiled objects.
It runs `mise run verify` with `MISE_ENV=ci`, and git's first branch set to `main`.

### Test profiles

Tools that only the tests start, such as the shells a script test runs, go in a mise profile of their own.
That is `mise.<profile>.toml` with its `mise.<profile>.lock`, and the caller names it in `test-profiles`.

- `test-profiles: test` gives `Build and test` `MISE_ENV=ci,test`.
- The other jobs, and a documentation-only build, keep `MISE_ENV=ci`.
- A repository loads the same profile locally through `.miserc.toml`, with `env = ["dev", "test"]`.

The mise cache key carries `MISE_ENV` and the hash of every `mise*.lock`.
So the build job's cache holds the profile's tools, and no other job restores it.

### Time limits

Each step has its own time limit, and the job has none, so the job ends within their sum.
The mbx step's 7 minutes apply to the restore and to the export separately.
A failed or timed-out export leaves the job green.
The export removes the Cargo target first, after every step that reads it.

## Caches

A cache step that fails does not fail the job, since the result comes from the build and tests.
One example is a save refused because the commit's key is already reserved on a re-run.
Only the build job writes the build cache.

### Namespace cache volume

The caller selects a persistent cache volume with `cache-volume`.
It must then supply its read-only safety label and a positive `cache-size` that matches its runner labels.
The render fragment derives the size label and the trim limit from one value, and render tests check they match.
The workflow refuses a run that lacks this configuration.

- The job runs with a cache volume tagged `rust-<repository>`, sized by `cache-size`.
- The volume keeps mise's installs, rustup's toolchains, Cargo's home, `target/` and mbx's store.
- The job commits the volume when it exits cleanly, and the next job forks the newest commit.
- Only a merge queue run, or a push, dispatch or schedule run on the default branch, commits the volume.
  So only reviewed code writes the toolchains and the store every later build runs.
- A pull request, or a run on another branch, reads the volume and never commits it.
- A last step keeps the volume under its size.
  After a passing build, `mbx gc` holds the store to a third of it, and `target/` is emptied once it passes half.

Parallel jobs that commit one cache tag overwrite each other: the last write wins, with no merge step
([Cache Volumes](https://namespace.so/docs/architecture/storage/cache-volumes)).
So `Publish checks` mounts the volume read-only.

### GitHub-hosted runners

The job restores the mise install cache and mbx's objects from the GitHub Actions cache instead.
`Publish checks` saves under its own key suffix.
A push to the default branch always builds, so the mbx cache saved from it stays current.

## Test selection

A pull request runs only the tests its diff can reach.
A merge queue run, a push and a dispatch run every test.

- Each changed file belongs to the deepest workspace package whose directory holds it.
- The selection is those packages, and every package that depends on them through a path dependency.
- A file that belongs to no package, such as `Cargo.lock` or a workflow, selects every test.

The selection reaches the repository's `test` task as a nextest filterset in `TEST_FILTERSET`, such as `package(=a) | package(=b)`.
A task that runs `cargo nextest run --workspace` passes it with `-E` and `--no-tests=pass`.
The catalog's `cargo test` ignores it and runs everything.

The whole workspace still builds.
Building fewer packages would resolve features per package, and rebuild dependencies the full build already has.

## Documentation-only changes

A pull request that changes only documentation builds nothing.
A `Changes` job on a light runner reads the changed paths with [dorny/paths-filter](https://github.com/dorny/paths-filter).

- Documentation is the root's Markdown files, `docs/` and `openspec/`.
- A file a Rust source names by its repository path is not documentation, such as a test input or an `include_str!` target.
  The name counts alone or at the end of a relative path.
- For such a pull request, the build job runs on a light runner and installs the tools without Rust.
  It runs whichever of `lint:md`, `lint:typos` and `specs` the repository defines.
- With `semver`, every pull request builds: `cargo package` ships documentation files, and the `Package` step checks it.

The `Verify` check reports a result either way.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `mise-version` | required | The mise release to install |
| `working-directory` | `.` | The directory that holds the crate's `mise.toml` |
| `advisories` | `true` | Runs `mise run deny:advisories` in `Static checks` |
| `semver` | `false` | Runs `mise run semver` and `cargo package`, for a published crate |
| `timeout-minutes` | `8` | Cancels a hung `Verify`, `Semver` or `Package` step |
| `build-runner` | `["ubuntu-latest"]` | JSON array of build labels |
| `read-only-runner` | `["ubuntu-latest"]` | JSON array of labels for builds that cannot commit cache state |
| `light-runner` | `ubuntu-latest` | The label for light jobs |
| `cache-volume` | `false` | Uses the supplied persistent build cache volume |
| `read-only-label` | empty | The safety label a persistent volume requires |
| `cache-size-label` | empty | The capacity label present in both runner arrays |
| `cache-size` | `0` | The volume size in GB, matching the capacity label |
| `test-profiles` | empty | Comma-separated mise profiles `Build and test` loads after `ci`, such as `test` |
