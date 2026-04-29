# apt-omakasui

APT repository for [omakasui](https://omakasui.org) configuration packages (`omakasui-*`), served via GitHub Pages at `core.omakasui.org`.

Metadata (`dists/`) and the package index (`index/packages.tsv`) live in this repo. Binary packages are stored as GitHub Release assets in [build-apt-omakasui](https://github.com/omakasui/build-apt-omakasui) and referenced directly via their full URL in the `Filename` field of the `Packages` index. A Cloudflare Worker on `core.omakasui.org` redirects `/pool/` requests to those release assets.

## Suites and architectures

| Suite | Distro | Architectures |
|---|---|---|
| `noble` | Ubuntu 24.04 | `amd64`, `arm64` |
| `noble-dev` | Ubuntu 24.04 (dev channel) | `amd64`, `arm64` |
| `trixie` | Debian 13 | `amd64`, `arm64` |
| `trixie-dev` | Debian 13 (dev channel) | `amd64`, `arm64` |

Dev suites include all stable packages as a base; dev-channel entries take precedence when present.

## Packages

| Package | Upstream | Suites | Architectures |
|---|---|---|---|
| `omakasui-aether` | [aether](https://github.com/bjarneo/aether) | noble, trixie | all |
| `omakasui-nvim` | [LazyVim](https://github.com/LazyVim/LazyVim) | noble, trixie | all |
| `omakasui-walker` | [walker](https://github.com/abenz1267/walker) | noble, trixie | all |
| `omakasui-zellij` | [zellij](https://github.com/zellij-org/zellij) | noble, trixie | all |

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
make promote-pkg PKG=omakasui-nvim                 # promote omakasui-nvim dev → stable
make prune-dry                                     # preview stale releases in build-apt-omakasui
```

## packages.tsv format

```
<suite> <arch> <name> <version> <url> <size> <md5> <sha1> <sha256> <control_b64> [<channel>]
```

`url` is the full GitHub Releases asset URL, stored as source of truth. When generating the `Packages` index, `update-index.sh` converts it to a pool-relative path (`pool/<tag>/<file>`). The Cloudflare Worker on `core.omakasui.org` redirects `pool/` requests to the corresponding GitHub Releases asset — no binaries are stored in this repo.

The `channel` field is `stable` (default) or `dev`. Pass `--channel dev` to `register-package.sh` to publish to the dev channel, which populates the `*-dev` suites.

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
echo "deb [signed-by=/etc/apt/keyrings/omakasui-core.gpg] https://core.omakasui.org $CODENAME main" \
  | sudo tee /etc/apt/sources.list.d/omakasui-core.list

sudo apt-get update
sudo apt-get install omakasui-nvim
```

