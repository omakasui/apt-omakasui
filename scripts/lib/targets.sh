#!/usr/bin/env bash
# Target catalog helpers.

TARGETS_FILE="${TARGETS_FILE:-index/targets.tsv}"

target_row() {
  local product="$1" suite="$2"
  awk -v p="$product" -v s="$suite" '$1 == p && $2 == s { print; exit }' "$TARGETS_FILE"
}

target_require() {
  local product="$1" suite="$2" row
  row=$(target_row "$product" "$suite")
  [[ -n "$row" ]] || { echo "ERROR: unknown target ${product}/${suite}" >&2; return 1; }
}

target_require_active() {
  local product="$1" suite="$2" row status
  row=$(target_row "$product" "$suite")
  [[ -n "$row" ]] || { echo "ERROR: unknown target ${product}/${suite}" >&2; return 1; }
  status=$(awk '{print $4}' <<< "$row")
  [[ "$status" == "active" ]] || { echo "ERROR: target ${product}/${suite} is ${status}" >&2; return 1; }
}

target_label() {
  target_row "$1" "$2" | awk '{print $3}'
}

target_list() {
  local status="${1:-}"
  if [[ -n "$status" ]]; then
    awk -v status="$status" '$4 == status { print $1 "/" $2 }' "$TARGETS_FILE"
  else
    awk '{ print $1 "/" $2 }' "$TARGETS_FILE"
  fi
}
