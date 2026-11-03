# gkzhb's Nix Configuration

This repository contains gkzhb's multi-host Nix configuration, organized with
[flake-parts](https://flake.parts/).

## Overview

The flake manages NixOS, nix-darwin, System Manager and standalone Home Manager
configurations, alongside packages, development shells and checks.

## Structure

```
.
├── flake.nix                    # Inputs, cache settings and mkFlake entry point
├── flake/
│   ├── default.nix              # Module imports and target platforms
│   ├── development.nix          # perSystem formatter, checks, devShells and hooks
│   ├── packages.nix             # perSystem exported packages and support matrix
│   ├── overlays.nix             # Existing, deliberately distinct overlay policies
│   └── hosts/                   # Top-level NixOS / System Manager / HM / Darwin outputs
├── .justfile                    # Just command runner tasks
├── hosts/                       # Per-host system and user configuration
├── packages/                    # Local package definitions
└── secrets/                     # Encrypted secrets managed by sops-nix
```

Host outputs remain top-level (`nixosConfigurations`, `systemConfigs`,
`homeConfigurations`, `darwinConfigurations`); they are not generated once per
platform. Shared development outputs use flake-parts `perSystem` for both Linux
architectures and both macOS architectures. Exported packages retain the narrower
matrix: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`. BrowserOS remains
`x86_64-linux` only.

To add an exported package, edit `flake/packages.nix`; to change development tools
or checks, edit `flake/development.nix`. Host module lists live in `flake/hosts/`,
while actual host settings stay in `hosts/`. Imports are explicit; package helpers
and host modules are not recursively auto-imported. Development tools continue to
use unmodified `legacyPackages`, separate from the exported packages' overlay and
license policy.

## External Flakes

This configuration leverages several external Nix flakes:

| Flake | Purpose |
|-------|---------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) | Main Nix package repository |
| [flake-parts](https://flake.parts/) | Modular flake outputs and per-platform development configuration |
| [home-manager](https://github.com/nix-community/home-manager) | User environment management |
| [sops-nix](https://github.com/Mic92/sops-nix) | Secret management with SOPS |
| [nix-ld](https://github.com/Mic92/nix-ld) | Run unpatched dynamic binaries |
| [llm-agents](https://github.com/numtide/llm-agents.nix) | LLM agents related packages |
| [minifluxng](https://git.sr.ht/~bwolf/miniflux.nix) | Miniflux RSS reader service |

## Features

- **System Services**: OpenSSH, PostgreSQL, Docker, Syncthing, Samba, qBittorrent, Miniflux, Node-RED, Tailscale, FRP client, Xray
- **Development Tools**: Fish shell, Neovim, Tmux, various CLI tools
- **Secret Management**: All sensitive data encrypted with sops-nix
- **Home Manager**: User-level configuration and systemd services

## Building

Use a shared command with a configuration name from `flake.nix`:

```bash
sudo just build-nixos home-nixos
sudo just build-nixos zhb-nixos
just build-system-manager devbox
just build-system-manager gkzhb-vps
just build-system-manager mido
just build-home-manager zhanghaibin.zhb
just build-home-manager zhb
just build-darwin gkzhb-MBP
```

Despite the historical `build-*` names, these commands **build and activate**
with `switch`. System Manager requests sudo itself; NixOS retains the existing
caller-provided sudo behavior. All commands use this repository as the flake
source, without requiring a symlink at `/etc/nixos`. Home Manager takes a
`homeConfigurations` key (usually a user name), not a machine hostname. Darwin
also updates its integrated Home Manager configuration.

Flake commands explicitly accept this repository's `nixConfig` (including its
substituters and trusted public keys) for each invocation. Review `flake.nix`
before running these commands; no global Nix trust setting is changed. The
CLI spellings differ, as verified against the locked inputs and installed tools:

| CLI | Supported spelling |
| --- | --- |
| `nix` (`build`, `develop`, `flake update/check`, `fmt`) | `--accept-flake-config` |
| `nixos-rebuild` (locked nixos-rebuild-ng) | `--accept-flake-config` |
| `home-manager` | `--option accept-flake-config true` |
| `darwin-rebuild` | `--option accept-flake-config true` |
| `system-manager` | `--nix-option accept-flake-config true` |

Home Manager, Darwin and System Manager do not directly recognize
`--accept-flake-config`; their supported options forward the equivalent Nix
setting. Legacy shortcuts inherit these arguments from the shared commands.

Existing shortcuts remain available and delegate to the shared commands:

| Existing command | Equivalent shared command |
| --- | --- |
| `just build` (also the default recipe) | `just build-nixos home-nixos` |
| `just build-zhb` | `just build-nixos zhb-nixos` |
| `just build-devbox` | `just build-system-manager devbox` |
| `just build-vps` | `just build-system-manager gkzhb-vps` |
| `just build-mido` | `just build-system-manager mido` |
| `just build-home <user>` | `just build-home-manager <user>` |
| `just build-darwin` | `just build-darwin gkzhb-MBP` |

For packages or checks **without activation**, use
`just build-package <target> [flags...]`, for example
`just build-package knots --no-link`. `build-aoci-code` uses this shared entry
point while keeping its invocation-local license permission.

Run the command-routing regression tests without building or activating systems:

```bash
just test-justfile
```

Check host names and the per-platform output support matrix without building or
activating systems:

```bash
nix eval --accept-flake-config --impure --json --expr \
  'import ./scripts/tests/flake-output-shape.nix { flakeRef = toString ./.; }'
```

## Formatting and Git Hooks

Nix files are formatted with `treefmt-nix` using `nixfmt`.

```bash
just format       # format all configured files
just check-format # verify formatting with nix flake check
just install-hooks
```

`just install-hooks` enters the development shell and installs the generated
pre-commit hook. On every commit, it formats staged `*.nix` files and runs
`git add` for those files, so their formatted content is included in the same
commit. The generated `.pre-commit-config.yaml` is ignored by Git.

## License

MIT License - see [LICENSE](LICENSE) file for details.
