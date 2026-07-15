# Build NixOS config
# run with sudo perm: sudo just build
build:
    nixos-rebuild switch --flake "/etc/nixos#home-nixos"

# update flake and package versions
# need to rebuild after running this
update:
  nix flake update

update-nix:
  nix flake update nixpkgs nix-ld sops-nix home-manager nix-darwin system-manager

# update secrets file after adding new hosts in .sops.yaml
update-secrets:
  sops updatekeys secrets/db.yaml

edit-secrets:
  sops secrets/db.yaml

build-devbox:
  nix run 'github:numtide/system-manager' -- switch --flake .#devbox --sudo

build-vps:
  system-manager switch --flake .#gkzhb-vps --sudo

# build standalone home-manager config
build-home user:
  home-manager switch --flake .#{{user}}

build-darwin:
  # nix run nix-darwin/master#darwin-rebuild -- switch
  darwin-rebuild switch --flake .#gkzhb-MBP
