#!/usr/bin/env bash
# sign-release.sh — Sign Release files for every suite with GPG.
# Usage: sign-release.sh --suites "<s1> <s2>" --key-id <fingerprint>
#        sign-release.sh --suites "<s1> <s2>" --key-url <url>

set -euo pipefail

SUITES=""
KEY_ID=""
KEY_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suites)  SUITES="$2";  shift 2 ;;
    --key-id)  KEY_ID="$2";  shift 2 ;;
    --key-url) KEY_URL="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$SUITES" ]] && { echo "ERROR: --suites is required"; exit 1; }

# If --key-id is not given, derive the fingerprint from the published key URL.
if [[ -z "$KEY_ID" ]]; then
  [[ -z "$KEY_URL" ]] && { echo "ERROR: --key-id or --key-url is required"; exit 1; }
  KEY_ID=$(curl -fsSL "$KEY_URL" \
    | gpg --with-colons --import-options show-only --import 2>/dev/null \
    | awk -F: '/^fpr:/ {print $10; exit}')
  [[ -z "$KEY_ID" ]] && { echo "ERROR: could not extract fingerprint from $KEY_URL" >&2; exit 1; }
  echo "Using key fingerprint: $KEY_ID"
fi

for suite in $SUITES; do
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="omakasui" \
    -o APT::FTPArchive::Release::Label="omakasui-packages" \
    -o APT::FTPArchive::Release::Suite="${suite}" \
    -o APT::FTPArchive::Release::Codename="${suite}" \
    -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="omakasui custom packages" \
    release "dists/${suite}" > "dists/${suite}/Release"

  gpg --default-key "$KEY_ID" \
      --armor --detach-sign --batch --yes \
      -o "dists/${suite}/Release.gpg" "dists/${suite}/Release"

  gpg --default-key "$KEY_ID" \
      --clearsign --batch --yes \
      -o "dists/${suite}/InRelease" "dists/${suite}/Release"

  echo "Signed: dists/${suite}/Release"
done

