# Build NixOS config
# run with sudo perm: sudo just build
build:
    nixos-rebuild switch --flake "/etc/nixos#home-nixos"

# Set network proxy before build
build-cn:
  export http_proxy=http://localhost:10881
  export https_proxy=http://localhost:10881
  export GOPROXY=https://goproxy.cn,direct
  just build

# update flake and package versions
# need to rebuild after running this
update:
  nix flake update

# update secrets file after adding new hosts in .sops.yaml
update-secrets:
  sops updatekeys secrets/db.yaml

edit-secrets:
  sops secrets/db.yaml

build-devbox:
  nix run 'github:numtide/system-manager' -- switch --flake .#devbox --sudo

build-vps:
  nix run 'github:numtide/system-manager' -- switch --flake .#gkzhb-vps --sudo

# build standalone home-manager config
build-home user:
  home-manager switch --flake .#{{user}}

build-darwin:
  # nix run nix-darwin/master#darwin-rebuild -- switch
  darwin-rebuild switch --flake .#gkzhb-MBP

build-darwin-cn:
  export https_proxy=http://localhost:10881
  export http_proxy=http://localhost:10881
  just build-darwin
