# macos-signing

`macos-signing` loads the CI Developer ID identities and the notary key for a macOS release job.
`macos-signing/delete` removes them again.

## Credentials

The identities and the App Store Connect notary key live only in 1Password,
in the Environment `VSH CI macOS signing`.
A release job fetches them through
[1Password Credential Broker](https://www.1password.dev/brokered-access/github-actions.md).
The broker checks the job's GitHub OIDC token against the repository's connection before it releases the values.
The connection names the repository, the `release` environment and the branch.

No repository holds a copy, so rotating a credential means changing it in that one Environment.

## Caller

The signing job names the `release` environment and may request an OIDC token.
It calls the action before it signs, and the cleanup last:

```yaml
jobs:
  sign:
    runs-on: macos-latest
    environment: release
    permissions:
      contents: write
      id-token: write # the token 1Password checks
    steps:
      - uses: victor-software-house/actions/macos-signing@<commit> # main, <date>
        with:
          workload-id: ${{ vars.OP_WORKLOAD_ID }}
          environment-id: ${{ vars.OP_ENVIRONMENT_ID }}
          integration-key: ${{ secrets.OP_INTEGRATION_KEY }}
          installer: true # only for productbuild
      # codesign --sign "Developer ID Application" …, then
      # xcrun notarytool submit … --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID"
      - if: always()
        uses: victor-software-house/actions/macos-signing/delete@<commit> # main, <date>
```

Build in a job without the `release` environment, and sign the artifact in another.
Then no dependency code runs while the identity is unlocked.
A pull request from a fork gets no secret, so it cannot reach the action.

## Steps

- It reads these values from the Environment, each on one line, the files base64-encoded:
  `MACOS_APP_P12_BASE64`, `MACOS_APP_P12_PASSWORD`, `MACOS_INSTALLER_P12_BASE64`,
  `MACOS_INSTALLER_P12_PASSWORD`, `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID`.
- It loads them as step outputs, so no later step sees them in its environment.
- It imports the Developer ID Application identity into a temporary keychain under `RUNNER_TEMP`.
  With `installer: true` it imports the Installer identity too.
- That keychain becomes the only one searched.
  `codesign` takes the first matching identity in the search list, whatever `--keychain` names.
- It writes the notary key to a private file.
  It sets `NOTARY_KEY_PATH`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` for the next steps.
- `macos-signing/delete` restores the login keychain, and deletes the temporary keychain and the key file.

## Inputs

| Input | Default | Effect |
|:--|:--|:--|
| `workload-id` | required | The repository's 1Password workload, its `OP_WORKLOAD_ID` variable |
| `environment-id` | required | The 1Password Environment that holds the signing set, `OP_ENVIRONMENT_ID` |
| `integration-key` | required | The organization secret `OP_INTEGRATION_KEY`, useless without a matching OIDC token |
| `installer` | `false` | Also imports the Developer ID Installer identity |
