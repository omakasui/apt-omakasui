#!/usr/bin/env bash
set -euo pipefail

errors=0
fail() { echo "ERROR: $*" >&2; errors=$((errors + 1)); }

while read -r product suite label status extra; do
  [[ -n "$product" && -n "$suite" && -n "$label" && -n "$status" && -z "${extra:-}" ]] || fail "invalid targets.tsv row: $product $suite $label $status ${extra:-}"
  [[ "$product" =~ ^[a-z0-9-]+$ && "$suite" =~ ^[a-z0-9-]+$ ]] || fail "invalid target name ${product}/${suite}"
  [[ "$status" == active || "$status" == deprecated ]] || fail "invalid status for ${product}/${suite}"
done < index/targets.tsv

declare -A seen=()
line=0
while IFS=' ' read -r product suite arch name version url size md5 sha1 sha256 control channel extra; do
  line=$((line + 1))
  [[ -n "$channel" && -z "${extra:-}" ]] || { fail "packages.tsv line ${line}: expected 12 fields"; continue; }
  awk -v p="$product" -v s="$suite" '$1==p && $2==s{found=1} END{exit !found}' index/targets.tsv || fail "line ${line}: unknown target ${product}/${suite}"
  [[ "$arch" == all || "$arch" == amd64 || "$arch" == arm64 ]] || fail "line ${line}: invalid arch ${arch}"
  [[ "$channel" == stable || "$channel" == dev ]] || fail "line ${line}: invalid channel ${channel}"
  key="${product}/${suite}/${arch}/${name}/${channel}"
  [[ -z "${seen[$key]:-}" ]] || fail "duplicate ${key}"
  seen[$key]=1
  [[ "$name" != omakub-* || "$product" == omabuntu ]] || fail "${name} leaked into ${product}/${suite}"
  [[ "$name" != omadeb-* || "$product" == omadeb ]] || fail "${name} leaked into ${product}/${suite}"
  if [[ "$name" == omari-* || "$name" == calamares-settings-omari ]]; then
    [[ "$product" == omari ]] || fail "${name} leaked into ${product}/${suite}"
  fi
done < index/packages.tsv

[[ $errors -eq 0 ]] || { echo "Validation failed: ${errors} error(s)" >&2; exit 1; }
echo "Validation OK: ${line} package entries"
