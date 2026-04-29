#!/usr/bin/env bash
# sign-release.sh — Generate Release, Release.gpg and InRelease for every suite,
# and export the public GPG key to omakasui.gpg.key.
#
# Usage:
#   sign-release.sh --suites "<suite1> <suite2>" --key-id <fingerprint>
#
# Requires: apt-ftparchive, gpg

set -euo pipefail

SUITES=""
KEY_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suites) SUITES="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$SUITES" ]] && { echo "ERROR: --suites is required"; exit 1; }
[[ -z "$KEY_ID" ]] && { echo "ERROR: --key-id is required"; exit 1; }

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

# Public key is served via keyrings.omakasui.org/omakasui-core.gpg.key