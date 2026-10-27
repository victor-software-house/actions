#!/bin/sh
# Runs pass or fail, so it continues past a missing keychain.
set -u
dir="${RUNNER_TEMP:?run only in a GitHub Actions job}/signing"
security list-keychains -d user -s login.keychain-db
security default-keychain -d user -s login.keychain-db
security delete-keychain "$dir/signing.keychain-db"
rm -rf "$dir"
