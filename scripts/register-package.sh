#!/usr/bin/env bash
# register-package.sh — Download .deb assets from a GitHub Release and register them in index/packages.tsv.
# Usage: register-package.sh --pkg <key> --version <ver> --suites "<s1> <s2>" [--produces "<p1> <p2>"] [--channel stable|dev]

set -euo pipefail

PKG=""
VERSION=""
SUITES=""
PRODUCES=""
REPO="omakasui/build-apt-omakasui"
CHANNEL="stable"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg)      PKG="$2";      shift 2 ;;
    --version)  VERSION="$2";  shift 2 ;;
    --suites)   SUITES="$2";   shift 2 ;;
    --produces) PRODUCES="$2"; shift 2 ;;
    --repo)     REPO="$2";     shift 2 ;;
    --channel)  CHANNEL="$2";  shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$PKG" ]]     && { echo "ERROR: --pkg is required";     exit 1; }
[[ -z "$VERSION" ]] && { echo "ERROR: --version is required"; exit 1; }
[[ -z "$SUITES" ]]  && { echo "ERROR: --suites is required";  exit 1; }
[[ "$CHANNEL" != "stable" && "$CHANNEL" != "dev" ]] && { echo "ERROR: --channel must be 'stable' or 'dev'"; exit 1; }

PRODUCED_PKGS="${PRODUCES:-$PKG}"

TAG="${PKG}-${VERSION}"
mkdir -p index
touch index/packages.tsv

_register_entry() {
  local suite="$1" arch="$2" name="$3" url="$4" deb="$5"

  local version size md5 sha1 sha256 control_b64
  version=$(dpkg-deb --field "$deb" Version)
  size=$(wc -c < "$deb")
  md5=$(md5sum       "$deb" | cut -d' ' -f1)
  sha1=$(sha1sum     "$deb" | cut -d' ' -f1)
  sha256=$(sha256sum "$deb" | cut -d' ' -f1)

  control_b64=$(dpkg-deb --field "$deb" | base64 -w0)

  # Replace any existing entry for this suite/arch/name/channel, then append the new one.
  awk -v s="$suite" -v a="$arch" -v n="$name" -v c="$CHANNEL" \
    '{ chan=(NF>=11)?$11:"stable"; if ($1==s && $2==a && $3==n && chan==c) next; print }' \
    index/packages.tsv > /tmp/packages.tmp || true
  echo "${suite} ${arch} ${name} ${version} ${url} ${size} ${md5} ${sha1} ${sha256} ${control_b64} ${CHANNEL}" \
    >> /tmp/packages.tmp
  mv /tmp/packages.tmp index/packages.tsv

  echo "Registered: ${url}"
}

for suite in $SUITES; do

  for produced in $PRODUCED_PKGS; do
    # Skip frozen suite+package combinations.
    if grep -qxF "${suite} ${produced}" index/freeze.list 2>/dev/null; then
      echo "SKIP: ${suite}/${produced} is frozen — edit index/freeze.list to release"
      continue
    fi

    _is_all=false

    # Try arch:all first.
    _pat="${produced}_${VERSION}-1+${suite}_all.deb"
    _tmpdir=$(mktemp -d)
    if gh release download "$TAG" \
         --repo "$REPO" --pattern "$_pat" --dir "$_tmpdir" 2>/dev/null; then
      _is_all=true
      _url="https://github.com/${REPO}/releases/download/${TAG}/${_pat}"
      _register_entry "$suite" "all" "$produced" "$_url" "$_tmpdir/$_pat"
    fi
    rm -rf "$_tmpdir"
    [[ "$_is_all" == "true" ]] && continue

    # Fall back to arch-specific assets.
    _arch_found=false
    for arch in amd64 arm64; do
      _tmpdir=$(mktemp -d)
      src="${produced}_${VERSION}-1+${suite}_${arch}.deb"
      _url="https://github.com/${REPO}/releases/download/${TAG}/${src}"

      if ! gh release download "$TAG" \
           --repo "$REPO" --pattern "$src" --dir "$_tmpdir" 2>/dev/null; then
        echo "Skipping ${arch}: no asset ${src} in release ${TAG}"
        rm -rf "$_tmpdir"
        continue
      fi

      _deb="$_tmpdir/$src"
      _register_entry "$suite" "$arch" "$produced" "$_url" "$_deb"
      rm -rf "$_tmpdir"
      _arch_found=true
    done
    if [[ "$_arch_found" == "false" ]]; then
      echo "ERROR: no arch-specific assets found for ${produced} ${VERSION} in release ${TAG}"
      exit 1
    fi
  done
done