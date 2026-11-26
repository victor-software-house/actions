# build-scope action

Decides whether a pull request or merge group changes anything the build reads, so a documentation-only change skips the build.

```yaml
changes:
  name: Changes
  if: ${{ github.event_name == 'pull_request' || github.event_name == 'merge_group' }}
  runs-on: ubuntu-26.04
  permissions:
    contents: read
    pull-requests: read
  outputs:
    build: ${{ steps.scope.outputs.build }}
  steps:
    - uses: actions/checkout@<commit> # <version>
      with:
        persist-credentials: false
        fetch-depth: ${{ github.event_name == 'merge_group' && '0' || '1' }}
    - id: scope
      uses: victor-software-house/actions/build-scope@<commit> # main, <date>
      with:
        go: true
```

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `go` | `false` | `true` makes a documentation file a build input when a Go source names it or may embed it |
| `swift` | `false` | `true` makes a documentation file a build input when a Swift source names it |

## Output

`build` is `false` when every changed path is documentation that no source reads, and `true` otherwise.

- Documentation is the root's Markdown files, `docs/`, `openspec/`, `tasks.yaml` and `.changeset/*.md`.
- A Go source reads a file when it names the file's path, or when a `//go:embed` line sits in the file's directory or a directory above it.
- A Swift source reads a file when it spells the path from the root in quotes, or as a relative path that climbs to the root.
- An input other than `true` or `false` fails the step.

## Needs

- A checkout of the repository, since the sources are searched with `git grep`.
  A merge group compares its head with its base through git, so a private repository's checkout takes the whole history there.
- `pull-requests: read`, for the path filter on a pull request.
- `jq` on the runner, as the GitHub-hosted images have.
