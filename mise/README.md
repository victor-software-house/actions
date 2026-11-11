# mise action

Installs the locked mise tools and saves the tools cache.
It sends github.com downloads through the organization's release mirror.
Use it in place of `jdx/mise-action`.
The organization secrets `RELEASE_MIRROR_URL` and `RELEASE_MIRROR_CI_KEY` hold the mirror's address and the key of a CI job's login:

```yaml
permissions:
  contents: read
  id-token: write
steps:
  - uses: victor-software-house/actions/mise@<commit> # main, <date>
    with:
      version: 2026.11.6
      mirror-url: ${{ secrets.RELEASE_MIRROR_URL }}
      mirror-key: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
```

The job exchanges its OIDC token for a session token, so it grants `id-token: write`.

## Downloads

- The action requests the job's OIDC token for the mirror's address.
  It exchanges that token at the mirror's `POST /token` for a session token that lasts six hours.
- With `mirror-key`, the exchange and every download carry the user name `ci.<key>`, which the mirror's edge rule admits from any runner.
  The key opens nothing alone: the mirror also checks the OIDC token on the exchange and the session token on each download.
- With the session token, mise fetches every github.com release asset from the mirror.
  `mise.lock`'s checksums verify each file.
- The login goes in the replacement URL, which mise sends as HTTP Basic credentials.
  mise redacts it from its logs, and the action masks the key and the token in every log.
- Every later step of the job can read both through `MISE_URL_REPLACEMENTS`.
  The session token opens only the mirror's downloads and lasts only until it expires.
- The action masks the mirror's address and host in every log, since it comes from a secret.
- A job with no OIDC token, or with no `mirror-url`, downloads from GitHub, and the action logs a notice.
  A fork's pull request gets no secrets, so it downloads from GitHub.
  A failed exchange downloads from GitHub too, with a warning.
  uv and Python then come from Astral's own mirror.

## mise itself

The action runs the organization's fork of `jdx/mise-action`,
[victor-software-house/mise-action](https://github.com/victor-software-house/mise-action).

- The fork applies the same URL replacements to its own downloads of mise.
- It restores the tools cache first, so a cache hit downloads nothing.
- It checks mise against mise's signed checksums, as upstream does.
- When the mirror fails, it warns and downloads from GitHub.

## Cache

The action saves the tools cache after the job.
A run on the default branch saves the cache that pull requests read.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `version` | required | The mise release to install |
| `mirror-url` | empty | The release mirror's address, and the OIDC token's audience; empty downloads from GitHub |
| `mirror-key` | empty | The key in the user name of the job's mirror login; empty sends none |
| `install` | `true` | `false` only sets mise up |
| `install_args` | empty | Arguments for `mise install`, such as one job's tools |
| `working_directory` | empty | The directory mise runs in |
| `cache` | `true` | `false` turns the tools cache off |
| `cache_key` | empty | The cache key template; empty takes the fork's default |
| `cache_save_post` | `true` | Saves the cache after the job; `false` saves it right after the install |
| `cache_save` | `true` | `false` only reads the cache |
| `cache_key_prefix` | `mise-v1` | The default key's prefix; change it to start a new cache |
| `sha256` | empty | The checksum the mise binary must match, beside the signed checksums |

Every input after `install` goes to the fork unchanged.
