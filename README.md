# apt-packages

APT repository for [omakasui](https://omakasui.org) custom packages, served via GitHub Pages at `core.omakasui.org`.

Metadata (`dists/`) and the package index (`index/packages.tsv`) live in this repo. Binary packages are stored as GitHub Release assets in [build-apt-packages](https://github.com/omakasui/build-apt-packages) and referenced directly via their full URL in the `Filename` field of the `Packages` index. No proxy or redirect layer required.

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
make info PKG=fzf                                  # inspect all entries for a package
make check                                         # count entries per suite/arch
make index                                         # regenerate Packages files
make rebuild GPG_KEY_ID=<fp>                       # regenerate + re-sign
make promote-pkg PKG=fzf                           # promote fzf dev → stable
make prune-dry                                     # preview stale releases in build-apt-packages
```

## packages.tsv format

```
<suite> <arch> <name> <version> <url> <size> <md5> <sha1> <sha256> <control_b64> [<channel>]
```

`url` is the full GitHub Releases asset URL, stored as source of truth. When generating the `Packages` index, `update-index.sh` converts it to a pool-relative path (`pool/<tag>/<file>`). The Cloudflare Worker on `core.omakasui.org` redirects `pool/` requests to the corresponding GitHub Releases asset — no binaries are stored in this repo.

The `channel` field is `stable` (default) or `dev`. Pass `--channel dev` to `register-package.sh` to publish to the dev channel, which populates the `*-dev` suites.

## User setup

```bash
curl -fsSL https://keyrings.omakasui.org/omakasui-core.gpg.key \
  | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/omakasui-core.gpg

echo "deb [signed-by=/etc/apt/trusted.gpg.d/omakasui-core.gpg] \
  https://core.omakasui.org $(. /etc/os-release && echo $VERSION_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/omakasui.list

sudo apt-get update
```
