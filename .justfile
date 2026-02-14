# Build NixOS config
# run with sudo perm: sudo just build
build:
    nixos-rebuild switch --flake "/etc/nixos#home-nixos"

# Set network proxy before build
build-cn:
  export http_proxy=http://localhost:10881
  export https_proxy=http://localhost:10881
  just build
