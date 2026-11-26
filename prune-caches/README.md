# prune-caches action

Deletes every cache entry of each key prefix on the run's ref, except the newest.
A build that saves a fresh entry on each default-branch run runs it afterwards, so one entry per prefix stays.

```yaml
prune:
  name: Prune superseded caches
  needs: build
  if: ${{ !cancelled() && needs.build.outputs.cache-saved == 'true' }}
  runs-on: ubuntu-26.04
  permissions:
    actions: write
  steps:
    - uses: victor-software-house/actions/prune-caches@<commit> # main, <date>
      with:
        prefixes: go- swift-
```

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `prefixes` | required | The key prefixes, separated by spaces; an empty value fails the step |
| `token` | `github.token` | The token `gh` deletes with |

## Needs

- `actions: write`, to delete caches.
- `gh` on the runner, as the GitHub-hosted images have.

`gh cache list` reads at most 100 entries for each prefix, newest kept.
