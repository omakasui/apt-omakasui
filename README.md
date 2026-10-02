# apt-omakasui

APT repository for [omakasui](https://omakasui.org) configuration packages (`omakasui-*`), served via GitHub Pages at `core.omakasui.org`.

Metadata and the package index (`index/packages.tsv`) live in this repo. Binary packages are stored as GitHub Release assets in [build-apt-omakasui](https://github.com/omakasui/build-apt-omakasui). Each product has an isolated repository path, and the Cloudflare Worker redirects namespaced `/pool/` requests to the assets.

## Products, suites and architectures

| Product path | Suite | Base | Architectures |
|---|---|---|---|
| `omabuntu` | `noble`, `resolute` | Ubuntu 24.04/26.04 | `amd64`, `arm64` |
| `omadeb` | `trixie` | Debian 13 | `amd64`, `arm64` |

Each product also exposes `*-dev` suites. Dev includes stable packages from the same product only, overridden by explicit dev entries.

## Packages

| Package | Upstream | Targets | Architectures |
|---|---|---|---|
| `omadeb-devtools` | [omadeb-devtools](https://github.com/omakasui/omakasui-devtools) | omadeb/trixie | all |
| `omadeb-nvim` | [omadeb-nvim](https://github.com/omakasui/omakasui-nvim) | omadeb/trixie | all |
| `omadeb-walker` | [omadeb-walker](https://github.com/omakasui/omakasui) | omadeb/trixie | all |
| `omadeb-zellij` | [omadeb-zellij](https://github.com/omakasui/omakasui-zellij) | omadeb/trixie | all |
| `omakasui-core-archive-keyring` | [omakasui-core-archive-keyring](https://github.com/omakasui/keyrings) | omabuntu/noble, omabuntu/resolute, omadeb/trixie | all |
| `omakasui-devtools` | [omakasui-devtools](https://github.com/omakasui/omakasui-devtools) | omabuntu/noble, omabuntu/resolute, omadeb/trixie | all |
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

## Maintenance

Package releases are published automatically from `build-apt-omakasui` through a
single `packages-updated` batch event. GitHub Actions also exposes manual workflows
for promotion and for exceptional index rebuilds or exact package removals.

Run `make help` for the small set of local inspection and verification commands:

```bash
make list                                          # show all packages in the index
make list-dev                                      # show packages not yet promoted to stable
make info PKG=omakasui-nvim                        # inspect all entries for a package
make status                                        # count entries per suite/arch
make check                                         # validate the manifest and run tests
make index                                         # regenerate Packages files
make rebuild GPG_KEY_ID=<fp>                       # regenerate + re-sign
make readme                                        # sync the README packages table
make prune-dry                                     # preview stale releases in build-apt-omakasui
```

## packages.tsv format

```
<product> <suite> <arch> <name> <version> <url> <size> <md5> <sha1> <sha256> <control_b64> <channel>
```

`url` is the full GitHub Releases asset URL, stored as source of truth. When generating the `Packages` index, `update-index.sh` converts it to a pool-relative path (`pool/<tag>/<file>`). The Cloudflare Worker on `core.omakasui.org` redirects `pool/` requests to the corresponding GitHub Releases asset — no binaries are stored in this repo.

The identity of an entry is product, suite, architecture, package and channel. Product targets and lifecycle state are defined in `index/targets.tsv`.

The legacy root suites (`/dists/noble`, `/dists/resolute`, `/dists/trixie`) are frozen snapshots. They receive no new packages. `index/legacy-retirement.yml` records the do-not-remove-before date of 2026-12-15 and the required consumer migrations.

## User setup

`omakasui-*` packages depend on their corresponding generic packages from `packages.omakasui.org`. Both keyring packages are needed: each one installs its signing key and its source in `/etc/apt/sources.list.d/`.

```bash
CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME)
wget -qO /tmp/omakasui-archive-keyring.deb \
  https://packages.omakasui.org/omakasui-archive-keyring/$CODENAME.deb
wget -qO /tmp/omakasui-core-archive-keyring.deb \
  https://core.omakasui.org/omakasui-core-archive-keyring/$CODENAME.deb
sudo dpkg -i /tmp/omakasui-archive-keyring.deb /tmp/omakasui-core-archive-keyring.deb

sudo apt-get update
sudo apt-get install omakasui-nvim
```

The product (`omabuntu` or `omadeb`) is set by the package for your distro. `/omakasui-core-archive-keyring/<suite>.deb` always redirects to the current release for that suite.
