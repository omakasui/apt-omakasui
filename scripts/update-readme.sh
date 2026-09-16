#!/usr/bin/env bash
# Update the README package table.
set -euo pipefail

README=README.md
TSV=index/packages.tsv
[[ -f "$README" && -f "$TSV" ]] || { echo "ERROR: README or manifest missing"; exit 1; }

table=$(mktemp); output=$(mktemp)
trap 'rm -f "$table" "$output"' EXIT
{
  echo '| Package | Upstream | Targets | Architectures |'
  echo '|---|---|---|---|'
  awk '$12=="stable" || $12=="dev" {print $4}' "$TSV" | sort -u | while IFS= read -r package; do
    targets=$(awk -v n="$package" '$4==n{print $1 "/" $2}' "$TSV" | sort -u | paste -sd, | sed 's/,/, /g')
    arches=$(awk -v n="$package" '$4==n{print $3}' "$TSV" | sort -u | paste -sd, | sed 's/,/, /g')
    control=$(awk -v n="$package" '$4==n{print $11;exit}' "$TSV")
    homepage=$(printf '%s' "$control" | base64 -d 2>/dev/null | awk '/^Homepage:/{sub(/^Homepage: /,"");print;exit}' || true)
    upstream="$package"; [[ -z "$homepage" ]] || upstream="[$package]($homepage)"
    printf '| `%s` | %s | %s | %s |\n' "$package" "$upstream" "$targets" "$arches"
  done
} > "$table"

awk -v table="$table" '
  /^\| Package \| Upstream \| (Suites|Targets) \| Architectures \|$/ {
    while ((getline line < table) > 0) print line; close(table); replacing=1; next
  }
  replacing && /^\|/ { next }
  replacing { replacing=0 }
  { print }
' "$README" > "$output"
mv "$output" "$README"
echo 'README packages table updated.'
