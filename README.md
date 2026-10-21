# gkzhb's Nix Configuration

This repository contains gkzhb's personal NixOS system configuration managed as a Nix Flake.

## Overview

This configuration provides a declarative and reproducible NixOS system setup for a personal workstation named `home-nixos`.

## Structure

```
.
├── flake.nix                    # Main flake definition
├── .justfile                    # Just command runner tasks
├── hosts/
│   └── home-nixos/
│       ├── configuration.nix    # System configuration
│       ├── hardware-configuration.nix  # Hardware-specific config
│       └── user.nix             # Home-manager user configuration
└── secrets/                     # Encrypted secrets managed by sops-nix
```

## External Flakes

This configuration leverages several external Nix flakes:

| Flake | Purpose |
|-------|---------|
| [nixpkgs](https://github.com/NixOS/nixpkgs) | Main Nix package repository |
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
`just build-package knots --no-link`. `build-alvr`,
`build-aoci-code` and `test-alvr-android` use this shared entry point while keeping
their special flags and license handling. The Android SDK/devShell workflows
remain separate.

Run the command-routing regression tests without building or activating systems:

```bash
just test-justfile
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
