#!/usr/bin/env bash
# Sign target Release files.
# Usage: sign-release.sh [--targets "product/suite ..."]
#        (--key-id <fingerprint> | --key-url <url>)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

TARGET_FILTER="" KEY_ID="" KEY_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets) TARGET_FILTER="$2"; shift 2 ;;
    --key-id) KEY_ID="$2"; shift 2 ;;
    --key-url) KEY_URL="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done
TARGET_FILTER="${TARGET_FILTER:-$(target_list active | tr '\n' ' ')}"
if [[ -z "$KEY_ID" ]]; then
  [[ -n "$KEY_URL" ]] || { echo "ERROR: --key-id or --key-url is required"; exit 1; }
  KEY_ID=$(curl -fsSL "$KEY_URL" | gpg --with-colons --import-options show-only --import 2>/dev/null | awk -F: '/^fpr:/{print $10;exit}')
  [[ -n "$KEY_ID" ]] || { echo "ERROR: could not extract fingerprint"; exit 1; }
fi

sign_dir() {
  local dir="$1" origin="$2" label="$3" published_suite="$4" description="$5"
  apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="$origin" \
    -o APT::FTPArchive::Release::Label="$label" \
    -o APT::FTPArchive::Release::Suite="$published_suite" \
    -o APT::FTPArchive::Release::Codename="$published_suite" \
    -o APT::FTPArchive::Release::Architectures="amd64 arm64" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="$description" \
    release "$dir" > "${dir}/Release"
  gpg --default-key "$KEY_ID" --armor --detach-sign --batch --yes -o "${dir}/Release.gpg" "${dir}/Release"
  gpg --default-key "$KEY_ID" --clearsign --batch --yes -o "${dir}/InRelease" "${dir}/Release"
  echo "Signed: ${dir}/Release"
}

for target in $TARGET_FILTER; do
  product=${target%%/*}; suite=${target#*/}; target_require_active "$product" "$suite"
  label=$(target_label "$product" "$suite")
  for published_suite in "$suite" "${suite}-dev"; do
    sign_dir "${product}/dists/${published_suite}" "Omakasui" "$label" "$published_suite" "${label} packages"
  done
done
