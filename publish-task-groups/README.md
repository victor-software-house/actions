# publish-task-groups action

Publishes each task group of a repository as a one-layer OCI artifact on GHCR.
A group is a directory under `root`, and its package is `ghcr.io/<owner>/<prefix><group>`.
A group whose content is the same as the `latest` tag's is not published again.

```yaml
permissions:
  contents: read
  packages: write
steps:
  - uses: actions/checkout@<commit> # <version>
    with:
      persist-credentials: false
  - uses: victor-software-house/actions/mise@<commit> # main, <date>
    with:
      version: 2026.11.6
  - id: publish
    uses: victor-software-house/actions/publish-task-groups@<commit> # main, <date>
```

The job needs mise on its path, and `jq` and GNU `tar`, which the Ubuntu runners have.
The action runs crane through `mise x`.

## Steps

For each directory directly under `root`, in name order:

1. It builds `<group>.tar.gz` from the directory, with the directory's name as the archive's top folder, sorted names, zero timestamps and owner 0.
   The same files always give the same bytes.
2. It reads the manifest of the package's `latest` tag.
   A package or tag that answers name unknown, manifest unknown or denied counts as not published yet, so the group counts as changed.
   GHCR answers denied for a package that does not exist.
   A real authentication failure then fails at the push, with crane's own error.
3. When the manifest's first layer has the archive's sha256 digest, the group is unchanged, and the digest it reports is the `latest` tag's.
4. Otherwise it appends the archive as the one layer of a new image tagged with the commit SHA, labels the image with `org.opencontainers.image.source`, and moves `latest` to it.
   The digest it reports is the new image's.

It fails when `root` has no group.
It checks every group name against `^[a-z0-9]+([._-][a-z0-9]+)*$` first, and when any name fails, it lists them in one error and publishes nothing.
It logs in to ghcr.io with the `token` input on stdin, and writes a table of the groups to the job summary.

## Using a group

A repository includes a published group by its digest:

```toml
[task_config]
includes = ["oci::ghcr.io/<owner>/tasks-<group>@sha256:<digest>"]
```

mise extracts the layer into the include root, so `groups/specs/budget.sh` becomes the task `specs:budget`.

## Inputs

| Input | Default | Meaning |
|:--|:--|:--|
| `root` | `groups` | The directory whose subdirectories are the groups |
| `prefix` | `tasks-` | The prefix of each package name |
| `owner` | the repository's owner | The GHCR owner of the packages, lowercased by the script |
| `source` | the repository's URL | The `org.opencontainers.image.source` label |
| `token` | `github.token` | The token that logs in to ghcr.io; it needs `packages: write` |
| `crane-version` | `0.22.1` | The crane release to run |

## Output

`groups` is a JSON object that maps each group to `{package, digest, changed}`:

```json
{"specs": {"package": "ghcr.io/<owner>/tasks-specs", "digest": "sha256:<digest>", "changed": true}}
```

`changed` is `true` when this run published the group.
