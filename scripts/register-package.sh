#!/usr/bin/env bash
# Register release assets in one target.
# Usage: register-package.sh --pkg <key> --version <ver> --product <product> --suite <suite>
#        [--produces "<p1> <p2>"] [--channel stable|dev] [--repo owner/repo]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

PKG="" VERSION="" PRODUCT="" SUITE="" PRODUCES="" CHANNEL="stable"
REPO="omakasui/build-apt-omakasui"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --product) PRODUCT="$2"; shift 2 ;;
    --suite) SUITE="$2"; shift 2 ;;
    --produces) PRODUCES="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PKG" ]] || { echo "ERROR: --pkg is required"; exit 1; }
[[ -n "$VERSION" ]] || { echo "ERROR: --version is required"; exit 1; }
[[ -n "$PRODUCT" ]] || { echo "ERROR: --product is required"; exit 1; }
[[ -n "$SUITE" ]] || { echo "ERROR: --suite is required"; exit 1; }
[[ "$CHANNEL" == stable || "$CHANNEL" == dev ]] || { echo "ERROR: invalid channel '${CHANNEL}'"; exit 1; }
target_require_active "$PRODUCT" "$SUITE"

PRODUCED_PKGS="${PRODUCES:-$PKG}"
TAG="${PKG}-${VERSION}"
mkdir -p index
touch index/packages.tsv

register_entry() {
  local arch="$1" name="$2" url="$3" deb="$4"
  local version size md5 sha1 sha256 control_b64 tmp
  version=$(dpkg-deb --field "$deb" Version)
  size=$(wc -c < "$deb")
  md5=$(md5sum "$deb" | cut -d' ' -f1)
  sha1=$(sha1sum "$deb" | cut -d' ' -f1)
  sha256=$(sha256sum "$deb" | cut -d' ' -f1)
  control_b64=$(dpkg-deb --field "$deb" | base64 -w0)
  tmp=$(mktemp)
  awk -v p="$PRODUCT" -v s="$SUITE" -v a="$arch" -v n="$name" -v c="$CHANNEL" \
    '{ chan=(NF>=12)?$12:"stable"; if ($1==p && $2==s && $3==a && $4==n && chan==c) next; print }' \
    index/packages.tsv > "$tmp"
  printf '%s %s %s %s %s %s %s %s %s %s %s %s\n' \
    "$PRODUCT" "$SUITE" "$arch" "$name" "$version" "$url" "$size" "$md5" "$sha1" "$sha256" "$control_b64" "$CHANNEL" >> "$tmp"
  mv "$tmp" index/packages.tsv
  echo "Registered: ${PRODUCT}/${SUITE} ${url}"
}

for produced in $PRODUCED_PKGS; do
  found=false
  pattern="${produced}_${VERSION}-1+${SUITE}_all.deb"
  tmpdir=$(mktemp -d)
  if gh release download "$TAG" --repo "$REPO" --pattern "$pattern" --dir "$tmpdir" 2>/dev/null; then
    url="https://github.com/${REPO}/releases/download/${TAG}/${pattern}"
    register_entry all "$produced" "$url" "$tmpdir/$pattern"
    found=true
  fi
  rm -rf "$tmpdir"
  [[ "$found" == true ]] && continue

  for arch in amd64 arm64; do
    pattern="${produced}_${VERSION}-1+${SUITE}_${arch}.deb"
    tmpdir=$(mktemp -d)
    if gh release download "$TAG" --repo "$REPO" --pattern "$pattern" --dir "$tmpdir" 2>/dev/null; then
      url="https://github.com/${REPO}/releases/download/${TAG}/${pattern}"
      register_entry "$arch" "$produced" "$url" "$tmpdir/$pattern"
      found=true
    else
      echo "Skipping ${arch}: no asset ${pattern} in release ${TAG}"
    fi
    rm -rf "$tmpdir"
  done
  [[ "$found" == true ]] || { echo "ERROR: no assets found for ${produced} ${VERSION}"; exit 1; }
done
