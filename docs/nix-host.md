# Nix host

`.github/workflows/nix-host.yml` builds one NixOS system behind one `Build` job.
It runs `nix flake check -L`, then `nix build -L <attribute> --out-link result`, on a native runner.
In a run with `upload` set, it then copies the paths that cache.nixos.org does not serve to the host's own Nix cache.

## Caller

A host repository's `ci.yml` calls the workflow on pull requests and merge queue entries, by commit.
Only a merge queue entry uploads:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  merge_group:

jobs:
  host:
    if: ${{ !github.event.pull_request.draft }}
    uses: victor-software-house/actions/.github/workflows/nix-host.yml@<commit> # main, <date>
    permissions:
      contents: read
    with:
      attribute: .#nixosConfigurations.<host>.config.system.build.toplevel
      upload: ${{ github.event_name == 'merge_group' }}
      cache-store: <the cache's s3:// store URL>
      substituter: <the cache's read URL>
      trusted-public-key: <the cache's public key>
      environment: ${{ github.event_name == 'merge_group' && 'nix-cache' || '' }}
    secrets:
      NIX_CACHE_ACCESS_KEY_ID: ${{ secrets.NIX_CACHE_ACCESS_KEY_ID }}
      NIX_CACHE_SECRET_ACCESS_KEY: ${{ secrets.NIX_CACHE_SECRET_ACCESS_KEY }}
      NIX_CACHE_SIGNING_KEY: ${{ secrets.NIX_CACHE_SIGNING_KEY }}
```

- The job needs only `contents: read`.
- A pull request passes no secrets and builds with the cache as a substituter, so it writes nothing.
- The upload secrets live in a GitHub environment, whose branch rules decide which refs can read them.
  A job that calls a reusable workflow cannot set `environment`, so the called job does, from the `environment` input.
  The caller passes the environment's name only for a merge queue entry, and an empty string otherwise.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `runner` | `["ubuntu-26.04-arm"]` | JSON array of final runner labels for the build |
| `attribute` | required | The flake attribute to build |
| `upload` | `false` | Copy the paths cache.nixos.org lacks to the cache after the build |
| `cache-store` | empty | The cache's `s3://` store URL, with its endpoint and region as query parameters and no credentials; required when `upload` is true |
| `substituter` | empty | The cache's read URL; empty adds no substituter |
| `trusted-public-key` | empty | The public key that verifies the cache's signatures; empty adds no key |
| `environment` | empty | The GitHub environment that holds the upload secrets; empty uses none |
| `timeout-minutes` | `30` | Cancels a hung build |

## Secrets

All three are optional, and all three are required when `upload` is true.
The first step fails the job with an error when `upload` is true and `cache-store` or any of them is empty.

| Secret | Use |
|:--|:--|
| `NIX_CACHE_ACCESS_KEY_ID` | The access key ID that writes to the cache |
| `NIX_CACHE_SECRET_ACCESS_KEY` | The secret access key that writes to the cache |
| `NIX_CACHE_SIGNING_KEY` | The secret key, in Nix's `name:base64` form, that signs the uploaded paths |

## Upload

1. `nix path-info -r ./result` lists the closure of the built system.
2. One `nix path-info --json --json-format 1 --store https://cache.nixos.org` call over the whole list reads each path's entry.
   The JSON maps a path to its info, or to `null` when cache.nixos.org does not serve it.
   The `null` paths are the ones to upload.
3. `nix store sign --key-file` signs those paths.
   The key is written to a mode 600 file under `RUNNER_TEMP`, and the step removes it when it exits.
4. `nix copy --no-recursive --to <cache-store>` uploads exactly those paths.
   It leaves out their references that cache.nixos.org serves, which clients fetch there.
   The access key and secret key are `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for that command only.
5. The step prints the number of uploaded paths and their total NAR size.

A closure that cache.nixos.org serves whole uploads nothing.
