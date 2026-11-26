# post-oidc-token action

Posts the job's OIDC token to a URL as a bearer token, with the URL as the token's audience.
An endpoint that checks the token's signature, issuer, audience and subject then knows which repository, workflow and ref called it, with no stored secret.

```yaml
deploy:
  name: Deploy
  if: ${{ github.event_name == 'push' }}
  runs-on: ubuntu-26.04
  permissions:
    id-token: write
  steps:
    - uses: victor-software-house/actions/post-oidc-token@<commit> # main, <date>
      with:
        url: https://deploy.example.com/hooks/deploy
```

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `url` | required | The URL that receives the token, and the token's audience |

## Attempts

- Each attempt requests a new token, because an endpoint that rejects a replayed token refuses the old one.
- The step makes up to five attempts, ten seconds apart, and fails after the fifth.
- Each attempt that fails prints whether GitHub gave no token, the answer held none, or the endpoint refused.
- The token is masked in the log before it is sent.

## Needs

`id-token: write`; without it the step fails before the first attempt.
