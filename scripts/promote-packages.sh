#!/usr/bin/env bash
# promote-packages.sh — Promote dev entries to stable in index/packages.tsv.
#
# Usage (single package):
#   promote-packages.sh --pkg <name> [--version <ver>] --suites "<s1> <s2>"
#
# Usage (all packages):
#   promote-packages.sh --all --suites "<s1> <s2>" [--exclude "<p1> <p2>"]
#
# Two-pass awk: pass 1 identifies (suite, arch, name) tuples being promoted;
# pass 2 drops superseded stable entries and rewrites dev entries as stable.

set -euo pipefail

PKG=""
VERSION=""
SUITES=""
EXCLUDE=""
ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg)     PKG="$2";     shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --suites)  SUITES="$2";  shift 2 ;;
    --exclude) EXCLUDE="$2"; shift 2 ;;
    --all)     ALL=true;     shift ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$SUITES" ]] && { echo "ERROR: --suites is required"; exit 1; }
[[ "$ALL" == "false" && -z "$PKG" ]] && { echo "ERROR: --pkg is required (or use --all)"; exit 1; }

touch index/packages.tsv

if [[ "$ALL" == "true" ]]; then
  awk -v excl="$EXCLUDE" -v suites="$SUITES" '
  BEGIN {
    n  = split(suites, sa, " "); for (i=1;i<=n;i++)  suite_set[sa[i]] = 1
    ne = split(excl,   ea, " "); for (i=1;i<=ne;i++) excl_set[ea[i]]  = 1
  }
  {
    n_fields = NF
    chan = (n_fields >= 11) ? $11 : "stable"
    is_target = (chan == "dev" && !excl_set[$3] && suite_set[$1])
    lines[NR] = $0; n_f[NR] = n_fields; is_promote[NR] = is_target
    if (is_target) promote_key[$1 " " $2 " " $3] = 1
  }
  END {
    for (i = 1; i <= NR; i++) {
      split(lines[i], f, " ")
      chan_i = (n_f[i] >= 11) ? f[11] : "stable"
      if (chan_i == "stable" && promote_key[f[1] " " f[2] " " f[3]]) continue
      if (is_promote[i]) {
        if (n_f[i] >= 11) { f[11] = "stable" } else { n_f[i]++; f[n_f[i]] = "stable" }
        line_out = f[1]; for (j = 2; j <= n_f[i]; j++) line_out = line_out " " f[j]
        print line_out; promoted++; continue
      }
      print lines[i]
    }
    if (promoted == 0)
      print "WARNING: no dev entries found for promotion." > "/dev/stderr"
    else
      printf "Promoted %d entr%s to stable.\n", promoted, (promoted == 1 ? "y" : "ies") > "/dev/stderr"
  }
  ' index/packages.tsv > /tmp/packages_promoted.tmp
else
  awk -v pkg="$PKG" -v ver="$VERSION" -v suites="$SUITES" '
  BEGIN {
    n = split(suites, sa, " "); for (i = 1; i <= n; i++) suite_set[sa[i]] = 1
  }
  {
    n_fields = NF
    chan = (n_fields >= 11) ? $11 : "stable"
    is_target = (chan == "dev" && $3 == pkg && (ver == "" || $4 == ver) && suite_set[$1])
    lines[NR] = $0; n_f[NR] = n_fields; is_promote[NR] = is_target
    if (is_target) promote_key[$1 " " $2 " " $3] = 1
  }
  END {
    for (i = 1; i <= NR; i++) {
      split(lines[i], f, " ")
      chan_i = (n_f[i] >= 11) ? f[11] : "stable"
      if (chan_i == "stable" && f[3] == pkg && promote_key[f[1] " " f[2] " " f[3]]) continue
      if (is_promote[i]) {
        if (n_f[i] >= 11) { f[11] = "stable" } else { n_f[i]++; f[n_f[i]] = "stable" }
        line_out = f[1]; for (j = 2; j <= n_f[i]; j++) line_out = line_out " " f[j]
        print line_out; promoted++; continue
      }
      print lines[i]
    }
    if (promoted == 0)
      print "WARNING: no matching dev entries found for promotion." > "/dev/stderr"
    else
      printf "Promoted %d entr%s for %s to stable.\n", promoted, (promoted == 1 ? "y" : "ies"), pkg > "/dev/stderr"
  }
  ' index/packages.tsv > /tmp/packages_promoted.tmp
fi

mv /tmp/packages_promoted.tmp index/packages.tsv
