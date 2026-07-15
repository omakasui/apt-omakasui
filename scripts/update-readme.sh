#!/usr/bin/env bash
# update-readme.sh — Sync the ## Packages table in README.md with index/packages.tsv.
# Usage: update-readme.sh [--suites "suite1 suite2 ..."] [--arches "arch1 arch2 ..."]

set -euo pipefail

README="README.md"
TSV="index/packages.tsv"

# Defaults — override via env or CLI flags.
_SUITES="${ALL_SUITES:-noble trixie resolute}"
_ARCHES="${ALL_ARCHES:-amd64 arm64}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --suites) _SUITES="$2"; shift 2 ;;
    --arches) _ARCHES="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

[[ ! -f "$TSV" ]]    && { echo "ERROR: ${TSV} not found";    exit 1; }
[[ ! -f "$README" ]] && { echo "ERROR: ${README} not found"; exit 1; }

# Build lookup sets from the canonical suites/arches lists.
declare -A _ALL_SUITES_SET _ALL_ARCHES_SET
for _s in $_SUITES; do _ALL_SUITES_SET[$_s]=1; done
for _a in $_ARCHES; do _ALL_ARCHES_SET[$_a]=1; done
_NUM_SUITES=${#_ALL_SUITES_SET[@]}
_NUM_ARCHES=${#_ALL_ARCHES_SET[@]}

declare -A PKG_SUITES PKG_ARCHES PKG_HOMEPAGE

while read -r suite arch name version url size md5 sha1 sha256 ctrl channel_raw; do
  channel="${channel_raw:-stable}"
  [[ "$channel" != "stable" ]] && continue

  PKG_SUITES[$name]="${PKG_SUITES[$name]:-} $suite"
  PKG_ARCHES[$name]="${PKG_ARCHES[$name]:-} $arch"

  if [[ -z "${PKG_HOMEPAGE[$name]:-}" && -n "${ctrl:-}" ]]; then
    hp=$(echo "$ctrl" | base64 -d 2>/dev/null \
      | awk '/^Homepage: /{ sub(/^Homepage: /, ""); print; exit }')
    PKG_HOMEPAGE[$name]="${hp:-}"
  fi
done < "$TSV"

# Normalize to sorted, deduplicated sets; apply "all" shorthand when applicable.
for name in "${!PKG_SUITES[@]}"; do
  mapfile -t _s < <(echo "${PKG_SUITES[$name]}" | tr ' ' '\n' | sort -u | grep -v '^$')
  mapfile -t _a < <(echo "${PKG_ARCHES[$name]}"  | tr ' ' '\n' | sort -u | grep -v '^$')

  # Suites: "all" if the package covers every canonical suite.
  _sc=0
  for s in "${_s[@]}"; do [[ -n "${_ALL_SUITES_SET[$s]:-}" ]] && _sc=$((_sc + 1)) || true; done
  if [[ $_sc -eq $_NUM_SUITES ]]; then
    PKG_SUITES[$name]="all"
  else
    _joined="${_s[*]}"; PKG_SUITES[$name]="${_joined// /, }"
  fi

  # Architectures: "all" if arch-independent OR if all binary arches are covered.
  if [[ ${#_a[@]} -eq 1 && "${_a[0]}" == "all" ]]; then
    PKG_ARCHES[$name]="all"
  else
    _ac=0
    for a in "${_a[@]}"; do [[ -n "${_ALL_ARCHES_SET[$a]:-}" ]] && _ac=$((_ac + 1)) || true; done
    if [[ $_ac -eq $_NUM_ARCHES ]]; then
      PKG_ARCHES[$name]="all"
    else
      _joined="${_a[*]}"; PKG_ARCHES[$name]="${_joined// /, }"
    fi
  fi
done

# Generate the canonical row for every package currently in the TSV.
# (Upstream text will be resolved later against the existing README rows.)
declare -A GENERATED_ROWS
# Read existing rows from the ## Packages section; preserve upstream column for existing entries.
declare -A EXISTING_ROWS EXISTING_UPSTREAM
while IFS= read -r row; do
  pkg=$(echo "$row" | grep -oP '^\| `\K[^`]+' || true)
  if [[ -n "${pkg:-}" ]]; then
    EXISTING_ROWS[$pkg]="$row"
    # Extract the upstream cell (column 3) and strip leading/trailing spaces.
    up=$(echo "$row" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')
    EXISTING_UPSTREAM[$pkg]="$up"
  fi
done < <(awk '/^## Packages/{found=1; next} found && /^## /{exit} found' "$README" \
         | grep -P '^\| `' || true)

# Re-generate rows, preserving the upstream cell for already-existing packages.
for pkg in "${!PKG_SUITES[@]}"; do
  local_upstream="${EXISTING_UPSTREAM[$pkg]:-}"
  if [[ -z "$local_upstream" ]]; then
    hp="${PKG_HOMEPAGE[$pkg]:-}"
    if [[ -n "$hp" ]]; then
      local_upstream="[${pkg}](${hp})"
    else
      local_upstream="${pkg}"
    fi
  fi
  GENERATED_ROWS[$pkg]="| \`${pkg}\` | ${local_upstream} | ${PKG_SUITES[$pkg]} | ${PKG_ARCHES[$pkg]} |"
done

# Detect any differences: new packages, removed packages, or changed rows.
changed=false

for pkg in "${!GENERATED_ROWS[@]}"; do
  if [[ "${EXISTING_ROWS[$pkg]:-}" != "${GENERATED_ROWS[$pkg]}" ]]; then
    if [[ -z "${EXISTING_ROWS[$pkg]:-}" ]]; then
      echo "Adding to README: ${pkg}"
    else
      echo "Updating in README: ${pkg}"
    fi
    changed=true
  fi
done

for pkg in "${!EXISTING_ROWS[@]}"; do
  if [[ -z "${PKG_SUITES[$pkg]:-}" ]]; then
    echo "Removing from README: ${pkg}"
    changed=true
  fi
done

if [[ "$changed" == "false" ]]; then
  echo "README packages table is up to date."
  exit 0
fi

TEMP_TABLE=$(mktemp)
TEMP_README=$(mktemp)
trap 'rm -f "$TEMP_TABLE" "$TEMP_README"' EXIT

{
  echo "| Package | Upstream | Suites | Architectures |"
  echo "|---|---|---|---|"
  mapfile -t SORTED_PKGS < <(printf '%s\n' "${!GENERATED_ROWS[@]}" | sort)
  for pkg in "${SORTED_PKGS[@]}"; do
    echo "${GENERATED_ROWS[$pkg]}"
  done
} > "$TEMP_TABLE"

# Replace the table from its header row to the last table line, then emit the sorted table.
awk -v table_file="$TEMP_TABLE" '
  /^\| Package \| Upstream \| Suites \| Architectures \|$/ {
    while ((getline line < table_file) > 0) print line
    close(table_file)
    in_table = 1
    next
  }
  in_table && /^\|/ { next }
  in_table           { in_table = 0 }
  { print }
' "$README" > "$TEMP_README"

mv "$TEMP_README" "$README"
echo "README packages table updated."
