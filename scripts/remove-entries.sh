#!/usr/bin/env bash
# Remove entries from one target.
# Usage: remove-entries.sh (--package <name> | --pattern <glob>) --product <product> --suite <suite>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

PACKAGE="" PATTERN="" PRODUCT="" SUITE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --package) PACKAGE="$2"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --product) PRODUCT="$2"; shift 2 ;;
    --suite) SUITE="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -n "$PRODUCT" && -n "$SUITE" ]] || { echo "ERROR: --product and --suite are required"; exit 1; }
[[ -n "$PACKAGE" || -n "$PATTERN" ]] || { echo "ERROR: --package or --pattern is required"; exit 1; }
[[ -z "$PACKAGE" || -z "$PATTERN" ]] || { echo "ERROR: selectors are mutually exclusive"; exit 1; }
target_require "$PRODUCT" "$SUITE"
[[ -f index/packages.tsv ]] || exit 0

before=$(wc -l < index/packages.tsv); tmp=$(mktemp)
awk -v product="$PRODUCT" -v suite="$SUITE" -v package="$PACKAGE" -v pattern="$PATTERN" '
  BEGIN { if(pattern!="") { gsub(/[][\\.^$()+?{}|]/,"\\\\&",pattern); gsub(/\*/,".*",pattern) } }
  {
    selected=($1==product && $2==suite)
    matches=(package!="") ? ($4==package) : ($4 ~ ("^" pattern "$"))
    if (!(selected && matches)) print
  }
' index/packages.tsv > "$tmp"
mv "$tmp" index/packages.tsv
after=$(wc -l < index/packages.tsv)
echo "Removed $((before-after)) entries from ${PRODUCT}/${SUITE}."
