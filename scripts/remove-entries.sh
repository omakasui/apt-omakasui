#!/usr/bin/env bash
# remove-entries.sh — Remove rows from index/packages.tsv by exact name
# or glob pattern, optionally filtered by suite.
#
# Usage:
#   remove-entries.sh --package <name> [--suites "<suite1> <suite2>"]
#   remove-entries.sh --pattern <glob> [--suites "<suite1> <suite2>"]

set -euo pipefail

PACKAGE=""
PATTERN=""
SUITES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package) PACKAGE="$2"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --suites)  SUITES="$2";  shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$PACKAGE" && -z "$PATTERN" ]] && {
  echo "ERROR: --package or --pattern is required"; exit 1
}
[[ -n "$PACKAGE" && -n "$PATTERN" ]] && {
  echo "ERROR: --package and --pattern are mutually exclusive"; exit 1
}

[[ ! -f index/packages.tsv ]] && { echo "Nothing to remove."; exit 0; }

BEFORE=$(wc -l < index/packages.tsv)

if [[ -n "$PACKAGE" ]]; then
  # Match the name field exactly (field 3, surrounded by spaces).
  if [[ -n "$SUITES" ]]; then
    cp index/packages.tsv /tmp/packages.tmp
    for suite in $SUITES; do
      # Keep lines from other suites untouched, remove only matching suite+name.
      grep -vF "^${suite} " /tmp/packages.tmp > /tmp/packages.other || true
      grep -F "^${suite} " /tmp/packages.tmp | grep -vF " ${PACKAGE} " \
        >> /tmp/packages.other || true
      mv /tmp/packages.other /tmp/packages.tmp
    done
    mv /tmp/packages.tmp index/packages.tsv
  else
    grep -vF " ${PACKAGE} " index/packages.tsv > /tmp/packages.tmp || true
    mv /tmp/packages.tmp index/packages.tsv
  fi
else
  # Convert glob to extended regex: * -> .*
  REGEX=" $(echo "$PATTERN" | sed 's/\*/.*/g') "
  if [[ -n "$SUITES" ]]; then
    cp index/packages.tsv /tmp/packages.tmp
    for suite in $SUITES; do
      # Keep lines from other suites, filter matching suite lines by pattern.
      grep -vF "^${suite} " /tmp/packages.tmp > /tmp/packages.other || true
      grep -F "^${suite} " /tmp/packages.tmp | grep -vE "${REGEX}" \
        >> /tmp/packages.other || true
      mv /tmp/packages.other /tmp/packages.tmp
    done
    mv /tmp/packages.tmp index/packages.tsv
  else
    grep -vE "${REGEX}" index/packages.tsv > /tmp/packages.tmp || true
    mv /tmp/packages.tmp index/packages.tsv
  fi
fi

AFTER=$(wc -l < index/packages.tsv)
REMOVED=$(( BEFORE - AFTER ))
echo "Removed ${REMOVED} entries (${PACKAGE:-$PATTERN}${SUITES:+ in $SUITES})."