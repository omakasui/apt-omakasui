#!/usr/bin/env bash
# Promote dev entries within one target.
# Usage: promote-packages.sh (--pkg <name> [--version <ver>] | --all)
#        --product <product> --suite <suite> [--exclude "<p1> <p2>"]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/targets.sh"

PKG="" VERSION="" PRODUCT="" SUITE="" EXCLUDE="" ALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg) PKG="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --product) PRODUCT="$2"; shift 2 ;;
    --suite) SUITE="$2"; shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --all) ALL=true; shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done
[[ -n "$PRODUCT" && -n "$SUITE" ]] || { echo "ERROR: --product and --suite are required"; exit 1; }
[[ "$ALL" == true || -n "$PKG" ]] || { echo "ERROR: --pkg or --all is required"; exit 1; }
[[ "$ALL" != true || -z "$PKG" ]] || { echo "ERROR: --pkg and --all are mutually exclusive"; exit 1; }
target_require_active "$PRODUCT" "$SUITE"

tmp=$(mktemp)
awk -v product="$PRODUCT" -v suite="$SUITE" -v pkg="$PKG" -v ver="$VERSION" \
    -v promote_all="$ALL" -v excluded="$EXCLUDE" '
  BEGIN { n=split(excluded,a," "); for(i=1;i<=n;i++) exclude[a[i]]=1; promoted=0 }
  {
    channel=(NF>=12)?$12:"stable"
    match_target=($1==product && $2==suite && channel=="dev")
    if (promote_all=="true") match_target=(match_target && !exclude[$4])
    else match_target=(match_target && $4==pkg && (ver=="" || $5==ver))
    if (match_target) { $12="stable"; promoted++ }
    print
  }
  END { if (promoted==0) print "WARNING: no dev entries found for promotion" > "/dev/stderr";
        else print "Promoted " promoted " entries" > "/dev/stderr" }
' index/packages.tsv > "$tmp"

# Deduplicate stable entries.
awk '{ key=$1 FS $2 FS $3 FS $4 FS ((NF>=12)?$12:"stable"); rows[key]=$0; order[++n]=key }
     END { for(i=1;i<=n;i++) if(!seen[order[i]]++) print rows[order[i]] }' "$tmp" > index/packages.tsv
rm -f "$tmp"
