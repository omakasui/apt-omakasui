#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/index"
cp "$ROOT/index/packages.tsv" "$ROOT/index/targets.tsv" "$SANDBOX/index/"

(cd "$SANDBOX" && bash "$ROOT/scripts/update-index.sh") >/dev/null

assert_absent() {
  local pattern="$1" file="$2"
  ! grep -q "^Package: ${pattern}" "$file" || { echo "ERROR: ${pattern} leaked into ${file}"; exit 1; }
}

for suite in noble resolute; do
  file="$SANDBOX/omabuntu/dists/$suite/main/binary-amd64/Packages"
  [[ -f "$file" ]] || { echo "ERROR: missing $file"; exit 1; }
  assert_absent 'omadeb-' "$file"; assert_absent 'omari-' "$file"
done

file="$SANDBOX/omadeb/dists/trixie/main/binary-amd64/Packages"
assert_absent 'omakub-' "$file"; assert_absent 'omari-' "$file"
file="$SANDBOX/omari/dists/trixie/main/binary-amd64/Packages"
assert_absent 'omakub-' "$file"; assert_absent 'omadeb-' "$file"

for target in omabuntu/noble omabuntu/resolute omadeb/trixie omari/trixie; do
  product=${target%/*}; suite=${target#*/}
  stable="$SANDBOX/$product/dists/$suite/main/binary-amd64/Packages"
  dev="$SANDBOX/$product/dists/${suite}-dev/main/binary-amd64/Packages"
  missing=$(comm -23 <(awk '/^Package:/{print $2}' "$stable" | sort -u) <(awk '/^Package:/{print $2}' "$dev" | sort -u))
  [[ -z "$missing" ]] || { echo "ERROR: stable fallback mismatch for $target: ${missing//$'\n'/ }"; exit 1; }
done

sed -i 's/^omari trixie Omari active$/omari trixie Omari deprecated/' "$SANDBOX/index/targets.tsv"
rm -rf "$SANDBOX/omari"
(cd "$SANDBOX" && bash "$ROOT/scripts/update-index.sh") >/dev/null
[[ ! -e "$SANDBOX/omari" ]] || { echo 'ERROR: deprecated target was regenerated'; exit 1; }

# Test dev override.
sed -i 's/^omari trixie Omari deprecated$/omari trixie Omari active/' "$SANDBOX/index/targets.tsv"
awk '!($1=="omadeb" && $2=="trixie" && $4=="omakasui-nvim" && $12=="dev") { print }
     $1=="omadeb" && $2=="trixie" && $4=="omakasui-nvim" && $12=="stable" && !done { $12="dev"; dev=$0; done=1 }
     END { print dev }' "$SANDBOX/index/packages.tsv" > "$SANDBOX/index/packages.tmp"
mv "$SANDBOX/index/packages.tmp" "$SANDBOX/index/packages.tsv"
(cd "$SANDBOX" && bash "$ROOT/scripts/update-index.sh" --targets omadeb/trixie) >/dev/null
[[ "$(grep -c '^Package: omakasui-nvim$' "$SANDBOX/omadeb/dists/trixie-dev/main/binary-amd64/Packages")" == 1 ]] || {
  echo 'ERROR: dev override did not suppress stable fallback'; exit 1;
}

# Test target-scoped mutations.
before_omabuntu=$(awk '$1=="omabuntu"' "$SANDBOX/index/packages.tsv" | sha256sum)
(cd "$SANDBOX" && bash "$ROOT/scripts/promote-packages.sh" --pkg omakasui-nvim --product omadeb --suite trixie) >/dev/null
after_omabuntu=$(awk '$1=="omabuntu"' "$SANDBOX/index/packages.tsv" | sha256sum)
[[ "$before_omabuntu" == "$after_omabuntu" ]] || { echo 'ERROR: promotion crossed product boundary'; exit 1; }
[[ "$(awk '$1=="omadeb" && $2=="trixie" && $4=="omakasui-nvim" && $12=="stable"{n++} END{print n+0}' "$SANDBOX/index/packages.tsv")" == 1 ]]

(cd "$SANDBOX" && bash "$ROOT/scripts/remove-entries.sh" --package omakasui-nvim --product omadeb --suite trixie) >/dev/null
! awk '$1=="omadeb" && $2=="trixie" && $4=="omakasui-nvim"{found=1} END{exit !found}' "$SANDBOX/index/packages.tsv"
awk '$1=="omabuntu" && $4=="omakasui-nvim"{found=1} END{exit !found}' "$SANDBOX/index/packages.tsv"

echo 'Repository isolation tests OK.'
