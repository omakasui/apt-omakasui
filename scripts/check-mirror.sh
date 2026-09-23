#!/usr/bin/env bash
# Verify that published APT metadata matches signatures and release assets.
# Usage: check-mirror.sh [--base-url <url>] [--report <file>]
#        [--key-url <url>] [--repo owner/repo]
# Checks active product suites and frozen legacy suites: InRelease signature,
# Packages hashes, release asset size/SHA256 and pool redirects.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

BASE_URL="https://core.omakasui.org" REPORT=""
KEY_URL="https://github.com/omakasui/keyrings/raw/refs/heads/main/omakasui-core.gpg.key"
REPO="omakasui/build-apt-omakasui"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url) BASE_URL="${2%/}"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    --key-url) KEY_URL="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
errors=0 checked=0
: > "$WORK/errors"
fail() { echo "ERROR: $*" >&2; echo "- $*" >> "$WORK/errors"; errors=$((errors + 1)); }

fetch() {
  local path="$1" out="$2"
  curl -fsSL --retry 3 -o "$out" "${BASE_URL}/${path}"
}

curl -fsSL --retry 3 "$KEY_URL" | gpg --dearmor > "$WORK/keyring.gpg"

# Suite directories: every active target plus the frozen legacy tree.
SUITE_DIRS=()
for target in $(target_list active); do
  product=${target%%/*}; suite=${target#*/}
  SUITE_DIRS+=("${product}/dists/${suite}" "${product}/dists/${suite}-dev")
done
for dir in dists/*/; do [[ -d "$dir" ]] && SUITE_DIRS+=("${dir%/}"); done

: > "$WORK/entries"
for dir in "${SUITE_DIRS[@]}"; do
  if ! fetch "${dir}/InRelease" "$WORK/InRelease"; then fail "${dir}: InRelease unavailable"; continue; fi
  if ! gpgv --keyring "$WORK/keyring.gpg" --output "$WORK/Release" "$WORK/InRelease" 2>/dev/null; then
    fail "${dir}: invalid InRelease signature"; continue
  fi
  for arch in amd64 arm64; do
    rel="main/binary-${arch}/Packages"
    expected=$(awk -v f="$rel" '/^SHA256:/{s=1; next} /^[^ ]/{s=0} s && $3==f {print $1}' "$WORK/Release")
    [[ -n "$expected" ]] || { fail "${dir}: ${rel} not listed in Release"; continue; }
    if ! fetch "${dir}/${rel}" "$WORK/Packages"; then fail "${dir}/${rel}: unavailable"; continue; fi
    [[ "$(sha256sum < "$WORK/Packages" | cut -d' ' -f1)" == "$expected" ]] || { fail "${dir}/${rel}: hash differs from Release"; continue; }
    awk -v d="${dir}/${rel}" '/^Filename:/{f=$2} /^Size:/{s=$2} /^SHA256:/{print d, f, s, $2}' "$WORK/Packages" >> "$WORK/entries"
  done
done

for tag in $(awk '{ n=split($2,u,"/"); print u[n-1] }' "$WORK/entries" | sort -u); do
  gh api "repos/${REPO}/releases/tags/${tag}" \
    --jq ".assets[] | \"${tag} \(.name) \(.size) \(.digest // \"\" | sub(\"^sha256:\"; \"\"))\"" \
    >> "$WORK/assets" 2>/dev/null || true
done
touch "$WORK/assets"

while read -r where filename size sha256; do
  checked=$((checked + 1))
  n=${filename//[^\/]/}; [[ "${#n}" -eq 2 && "$filename" == pool/* ]] || { fail "${where}: unexpected Filename ${filename}"; continue; }
  tag=${filename#pool/}; tag=${tag%%/*}; file=${filename##*/}
  read -r _ _ asset_size asset_sha < <(awk -v t="$tag" -v f="$file" '$1==t && $2==f' "$WORK/assets") || true
  if [[ -z "${asset_size:-}" ]]; then fail "${where}: ${file} missing from release ${tag}"
  elif [[ "$asset_size" != "$size" ]]; then fail "${where}: ${file} size ${size} != asset ${asset_size}"
  elif [[ -n "$asset_sha" && "$asset_sha" != "$sha256" ]]; then fail "${where}: ${file} SHA256 differs from asset"
  fi
  asset_size="" asset_sha=""
done < "$WORK/entries"

# Pool redirects through the Worker, once per unique file.
while read -r filename; do
  tag=${filename#pool/}; tag=${tag%%/*}
  want="https://github.com/${REPO}/releases/download/${tag}/${filename##*/}"
  got=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' -I --retry 3 "${BASE_URL}/${filename}" || true)
  [[ "$got" == "302 ${want}" ]] || fail "redirect ${filename}: got '${got}'"
done < <(awk '{print $2}' "$WORK/entries" | sort -u)

summary="Checked ${#SUITE_DIRS[@]} suites and ${checked} package entries (${BASE_URL}): ${errors} error(s)."
echo "$summary"
if [[ -n "$REPORT" ]]; then
  { echo "$summary"; echo; sort -u "$WORK/errors"; } > "$REPORT"
fi
[[ $errors -eq 0 ]]
