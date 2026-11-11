# mbx-cache action

Sets up [mbx](https://mr-boxington.jdx.dev) with the organization's remote cache, an R2 bucket.
The release mirror signs short-lived credentials for it, scoped to the calling repository.
Use it in place of `jdx/mr-boxington-action`.

```yaml
permissions:
  contents: read
  id-token: write
steps:
  - uses: victor-software-house/actions/mbx-cache@<commit> # main, <date>
    with:
      endpoint: ${{ secrets.RELEASE_MIRROR_URL }}
      key: ${{ secrets.RELEASE_MIRROR_CI_KEY }}
      ttl-minutes: 120
```

## What it does

1. It requests the job's OIDC token for `<endpoint>/mbx/credentials` and posts it there.
   With `key`, it sends the token as the password of the user name `ci.<key>`, which the mirror's edge rule admits.
2. The mirror answers credentials for the repository's own prefix in the bucket.
   They are read-write only on a push to the default branch, and read-only on every other event.
3. The action masks every value of the answer, then exports `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` and the `MBX_REMOTE_*` settings for later steps.
4. It runs mr-boxington-action with `backend: remote`, which keeps those settings and runs `mbx doctor`.

A job with no OIDC token, an empty `endpoint`, or no answer from the mirror gets a warning, and mbx builds with its local store only.
A fork's pull request gets neither secret nor OIDC token, so it builds locally.

The credentials cannot be renewed, so `ttl-minutes` must outlast the job.
mbx reads only `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_SESSION_TOKEN`, so the action replaces any AWS credentials an earlier step set; run it after the job's AWS steps, or in a job of its own.
Every later step of the job can read them; they reach only the repository's own prefix and expire.

## Inputs

| Input | Default | Meaning |
|:--|:--|:--|
| `endpoint` | required | The release mirror's address, from an organization secret; empty builds locally |
| `key` | empty | The key in the user name of the job's mirror login |
| `ttl-minutes` | required | How long the credentials last, from 10 to 360 |
| `generation` | `v1` | The cache generation; a new one starts an empty namespace |
| `version` | `1.30.0` | The mbx release mr-boxington-action installs |
