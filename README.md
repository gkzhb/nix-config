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

Build the system configuration with Just:

```bash
just build
```

Or directly with Nix:

```bash
sudo nixos-rebuild switch --flake .#home-nixos
```

## License

MIT License - see [LICENSE](LICENSE) file for details.
