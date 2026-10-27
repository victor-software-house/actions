#!/bin/sh
# The identities go into a temporary keychain that becomes the only one
# searched, so signing by name finds them and nothing else: codesign takes the
# first matching identity in the search list, whatever --keychain names.
# macos-signing/delete removes it. The notary key goes to a private file whose
# path, with its ids, reaches the next steps through GITHUB_ENV.
set -eu
dir="${RUNNER_TEMP:?run only in a GitHub Actions job}/signing"
keychain="$dir/signing.keychain-db"
password=$(uuidgen)
mkdir -m 700 "$dir"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"

identity() {
  printf %s "$1" | base64 --decode > "$dir/identity.p12"
  security import "$dir/identity.p12" -k "$keychain" -f pkcs12 -P "$2" -T /usr/bin/codesign -T /usr/bin/productbuild
  rm "$dir/identity.p12"
}
identity "${MACOS_APP_P12_BASE64:?the Environment lacks MACOS_APP_P12_BASE64}" "$MACOS_APP_P12_PASSWORD"
if [ -n "$MACOS_INSTALLER_P12_BASE64" ]; then
  identity "$MACOS_INSTALLER_P12_BASE64" "$MACOS_INSTALLER_P12_PASSWORD"
fi
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" > /dev/null
security list-keychains -d user -s "$keychain"
security default-keychain -d user -s "$keychain"
security find-identity -v "$keychain"

printf %s "${NOTARY_KEY_P8_BASE64:?the Environment lacks NOTARY_KEY_P8_BASE64}" | base64 --decode > "$dir/AuthKey.p8"
{
  echo "NOTARY_KEY_PATH=$dir/AuthKey.p8"
  echo "NOTARY_KEY_ID=$NOTARY_KEY_ID"
  echo "NOTARY_ISSUER_ID=$NOTARY_ISSUER_ID"
} >> "$GITHUB_ENV"
