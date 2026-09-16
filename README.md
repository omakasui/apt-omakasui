# apt-omakasui

APT repository for [omakasui](https://omakasui.org) configuration packages (`omakasui-*`), served via GitHub Pages at `core.omakasui.org`.

Metadata and the package index (`index/packages.tsv`) live in this repo. Binary packages are stored as GitHub Release assets in [build-apt-omakasui](https://github.com/omakasui/build-apt-omakasui). Each product has an isolated repository path, and the Cloudflare Worker redirects namespaced `/pool/` requests to the assets.

## Products, suites and architectures

| Product path | Suite | Base | Architectures |
|---|---|---|---|
| `omabuntu` | `noble`, `resolute` | Ubuntu 24.04/26.04 | `amd64`, `arm64` |
| `omadeb` | `trixie` | Debian 13 | `amd64`, `arm64` |
| `omari` | `trixie` | Debian 13 | `amd64`, `arm64` |

Each product also exposes `*-dev` suites. Dev includes stable packages from the same product only, overridden by explicit dev entries.

## Packages

| Package | Upstream | Targets | Architectures |
|---|---|---|---|
| `calamares-settings-omari` | [calamares-settings-omari](https://codeberg.org/omakasui/calamares-settings-omari) | omari/trixie | all |
| `omadeb-devtools` | [omadeb-devtools](https://github.com/omakasui/omakasui-devtools) | omadeb/trixie | all |
| `omadeb-nvim` | [omadeb-nvim](https://github.com/omakasui/omakasui-nvim) | omadeb/trixie | all |
| `omadeb-walker` | [omadeb-walker](https://github.com/omakasui/omakasui) | omadeb/trixie | all |
| `omadeb-zellij` | [omadeb-zellij](https://github.com/omakasui/omakasui-zellij) | omadeb/trixie | all |
| `omakasui-archive-keyring` | [omakasui-archive-keyring](https://codeberg.org/omakasui/omakasui-archive-keyring) | omari/trixie | all |
| `omakasui-nvim` | [omakasui-nvim](https://github.com/omakasui/omakasui-nvim) | omabuntu/noble, omabuntu/resolute, omadeb/trixie | all |
| `omakasui-walker` | [omakasui-walker](https://github.com/omakasui/omakasui) | omabuntu/noble, omadeb/trixie | all |
| `omakasui-zellij` | [omakasui-zellij](https://github.com/omakasui/omakasui-zellij) | omabuntu/noble, omabuntu/resolute, omadeb/trixie | all |
| `omakub-devtools` | [omakub-devtools](https://github.com/omakasui/omakasui-devtools) | omabuntu/noble, omabuntu/resolute | all |
| `omakub-nvim` | [omakub-nvim](https://github.com/omakasui/omakasui-nvim) | omabuntu/noble, omabuntu/resolute | all |
| `omakub-walker` | [omakub-walker](https://github.com/omakasui/omakasui) | omabuntu/noble, omabuntu/resolute | all |
| `omakub-zellij` | [omakub-zellij](https://github.com/omakasui/omakasui-zellij) | omabuntu/noble, omabuntu/resolute | all |

## Copyright and licensing

The packages distributed through this repository are **third-party software**. Each package remains the property of its respective upstream author(s) and is subject to its own license.

This repository does not claim any ownership over the upstream software. Its sole purpose is to make installation easier on systems running Omakasui by providing pre-built `.deb` packages. All trademarks, copyrights, and licenses belong to their respective holders as listed in the upstream column of the packages table above.

If you are an upstream maintainer and have concerns about the distribution of your software here, please open an issue or contact the omakasui project directly.

## Scripts and local workflow

Run `make help` from the repo root for a full list of available targets. Common ones:

```bash
make list                                          # show all packages in the index
make list-dev                                      # show packages not yet promoted to stable
make info PKG=omakasui-nvim                        # inspect all entries for a package
make check                                         # count entries per suite/arch
make index                                         # regenerate Packages files
make rebuild GPG_KEY_ID=<fp>                       # regenerate + re-sign
make promote-pkg PKG=omakasui-nvim PRODUCT=omadeb SUITE=trixie
make readme                                        # sync the README packages table
make prune-dry                                     # preview stale releases in build-apt-omakasui
```

## packages.tsv format

```
<product> <suite> <arch> <name> <version> <url> <size> <md5> <sha1> <sha256> <control_b64> <channel>
```

`url` is the full GitHub Releases asset URL, stored as source of truth. When generating the `Packages` index, `update-index.sh` converts it to a pool-relative path (`pool/<tag>/<file>`). The Cloudflare Worker on `core.omakasui.org` redirects `pool/` requests to the corresponding GitHub Releases asset — no binaries are stored in this repo.

The identity of an entry is product, suite, architecture, package and channel. Product targets and lifecycle state are defined in `index/targets.tsv`.

The legacy root suites (`/dists/noble`, `/dists/resolute`, `/dists/trixie`) are frozen snapshots. They receive no new packages. `index/legacy-retirement.yml` prevents removal before 2026-12-15 and records the required consumer migrations.

## User setup

`omakasui-*` packages depend on their corresponding generic packages from `packages.omakasui.org`. Both sources must be configured:

```bash
# Import both GPG keys
sudo install -dm 755 /etc/apt/keyrings
curl -fsSL https://keyrings.omakasui.org/omakasui-packages.gpg.key \
  | gpg --dearmor | sudo tee /etc/apt/keyrings/omakasui.gpg > /dev/null
curl -fsSL https://keyrings.omakasui.org/omakasui-core.gpg.key \
  | gpg --dearmor | sudo tee /etc/apt/keyrings/omakasui-core.gpg > /dev/null

# Add both sources
CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME)
echo "deb [signed-by=/etc/apt/keyrings/omakasui.gpg] https://packages.omakasui.org $CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/omakasui.list
PRODUCT=omadeb # omabuntu, omadeb, or omari
echo "deb [signed-by=/etc/apt/keyrings/omakasui-core.gpg] https://core.omakasui.org/$PRODUCT $CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/omakasui-core.list

sudo apt-get update
sudo apt-get install omakasui-nvim
```
