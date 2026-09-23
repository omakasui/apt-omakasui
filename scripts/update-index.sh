#!/usr/bin/env bash
# Generate target Packages indexes.
# Usage: update-index.sh [--targets "product/suite ..."]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

TARGET_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --targets) TARGET_FILTER="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -f index/packages.tsv ]] || { echo "ERROR: index/packages.tsv not found"; exit 1; }
TARGET_FILTER="${TARGET_FILTER:-$(target_list active | tr '\n' ' ')}"

write_entry() {
  local dir="$1"
  printf "Package: %s\nVersion: %s\nArchitecture: %s\n" "$name" "$version" "$arch" >> "${dir}/Packages"
  printf '%s\n' "$control" | grep -v -E '^(Package|Version|Architecture):' >> "${dir}/Packages"
  printf "Filename: %s\nSize: %s\nMD5sum: %s\nSHA1: %s\nSHA256: %s\n\n" \
    "$filename" "$size" "$md5" "$sha1" "$sha256" >> "${dir}/Packages"
}

for target in $TARGET_FILTER; do
  product=${target%%/*}; suite=${target#*/}
  target_require_active "$product" "$suite"
  for binary_arch in amd64 arm64; do
    stable_dir="${product}/dists/${suite}/main/binary-${binary_arch}"
    dev_dir="${product}/dists/${suite}-dev/main/binary-${binary_arch}"
    mkdir -p "$stable_dir" "$dev_dir"
    : > "${stable_dir}/Packages"; : > "${dev_dir}/Packages"

    declare -A dev_packages=()
    while IFS=' ' read -r p s arch name _version _url _size _md5 _sha1 _sha256 _control channel _ignored; do
      [[ "$p" == "$product" && "$s" == "$suite" ]] || continue
      [[ "$arch" == "$binary_arch" || "$arch" == all ]] || continue
      [[ "${channel:-stable}" == dev ]] && dev_packages["${binary_arch}:${name}"]=1
    done < index/packages.tsv

    while IFS=' ' read -r p s arch name version url size md5 sha1 sha256 control_b64 channel _ignored; do
      [[ "$p" == "$product" && "$s" == "$suite" ]] || continue
      [[ "$arch" == "$binary_arch" || "$arch" == all ]] || continue
      channel="${channel:-stable}"
      dir="$stable_dir"; [[ "$channel" == dev ]] && dir="$dev_dir"
      filename="$url"
      if [[ "$url" == https://github.com/*/releases/download/*/* ]]; then
        tag="${url%/*}"; tag="${tag##*/}"
        filename="pool/${tag}/${url##*/}"
      fi
      control=$(printf '%s' "$control_b64" | base64 -d 2>/dev/null || true)
      write_entry "$dir"
      if [[ "$channel" == stable && -z "${dev_packages["${binary_arch}:${name}"]:-}" ]]; then write_entry "$dev_dir"; fi
    done < index/packages.tsv
    unset dev_packages

    for dir in "$stable_dir" "$dev_dir"; do
      gzip -n -k -f "${dir}/Packages"; xz -k -f "${dir}/Packages"
      echo "Generated: ${dir}/Packages ($(grep -c '^Package:' "${dir}/Packages" || true) entries)"
    done
  done
done
