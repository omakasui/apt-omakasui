#!/usr/bin/env bash
# prune-releases.sh — Report (and optionally delete) stale GitHub Releases in build-apt-packages.
# A release is kept if referenced in packages.tsv or is the latest for its build package.
# Usage: prune-releases.sh [--delete] [--repo <owner/repo>] [--limit <n>]

set -euo pipefail

DELETE=false
REPO="omakasui/build-apt-omakasui"
TSV="index/packages.tsv"
LIMIT=500

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete) DELETE=true;  shift ;;
    --repo)   REPO="$2";    shift 2 ;;
    --limit)  LIMIT="$2";   shift 2 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ ! -f "$TSV" ]] && {
  echo "ERROR: $TSV not found. Run from the apt-packages repo root." >&2
  exit 1
}

# All tags currently referenced in packages.tsv.
mapfile -t ACTIVE_TAGS < <(
  awk '{print $5}' "$TSV" \
    | grep -oP 'releases/download/\K[^/]+' \
    | sort -u
)

echo "Active release tags referenced in packages.tsv: ${#ACTIVE_TAGS[@]}"

# Fetch all releases ordered newest-first, then derive a sorted copy for comm.
mapfile -t ALL_TAGS_ORDERED < <(
  gh release list --repo "$REPO" --limit "$LIMIT" --json tagName \
    --jq '.[].tagName'
)
mapfile -t ALL_TAGS_SORTED < <(printf '%s\n' "${ALL_TAGS_ORDERED[@]}" | sort)

echo "Total releases in ${REPO}: ${#ALL_TAGS_SORTED[@]}"

# Derive build-package names from TSV URLs (tag format: <pkg>-<version>).
declare -A BUILD_PKGS
while IFS=' ' read -r _s _a _n version url _rest; do
  tag=$(printf '%s' "$url" | grep -oP 'releases/download/\K[^/]+' || true)
  [[ -z "$tag" ]] && continue
  build_pkg="${tag%-${version}}"
  [[ -n "$build_pkg" ]] && BUILD_PKGS["$build_pkg"]=1
done < "$TSV"

# Protect the most recent release tag for each build package.
declare -A LATEST_TAG
for tag in "${ALL_TAGS_ORDERED[@]}"; do
  for build_pkg in "${!BUILD_PKGS[@]}"; do
    if [[ "$tag" == "${build_pkg}-"* ]] && [[ -z "${LATEST_TAG[$build_pkg]:-}" ]]; then
      LATEST_TAG[$build_pkg]="$tag"
      break
    fi
  done
done

# Protected = referenced in TSV + latest per build package.
declare -A PROTECTED
for tag in "${ACTIVE_TAGS[@]}";        do PROTECTED[$tag]=1; done
for tag in "${LATEST_TAG[@]}";         do PROTECTED[$tag]=1; done

# Stale = in repo but not protected.
mapfile -t STALE < <(
  comm -23 \
    <(printf '%s\n' "${ALL_TAGS_SORTED[@]}") \
    <(printf '%s\n' "${!PROTECTED[@]}" | sort)
)

if [[ ${#STALE[@]} -eq 0 ]]; then
  echo "No stale releases found."
  exit 0
fi

echo ""
echo "Stale releases (${#STALE[@]}):"
for tag in "${STALE[@]}"; do
  echo "  $tag"
done

if [[ "$DELETE" == "false" ]]; then
  echo ""
  echo "Dry-run: no releases deleted. Re-run with --delete to remove them."
  exit 0
fi

echo ""
echo "Deleting stale releases..."
DELETED=0
for tag in "${STALE[@]}"; do
  echo "  Deleting: $tag"
  gh release delete "$tag" --repo "$REPO" --yes --cleanup-tag
  (( DELETED++ )) || true
done
echo ""
echo "Done. Deleted ${DELETED} stale release(s)."
