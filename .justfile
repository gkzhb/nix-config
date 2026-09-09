# Build NixOS config
# run with sudo perm: sudo just build
build:
    nixos-rebuild switch --flake "/etc/nixos#home-nixos"

build-zhb:
    nixos-rebuild switch --flake "/etc/nixos#zhb-nixos"

# Build the pinned ALVR master snapshot without activating the system.
build-alvr:
    nix build .#alvr --cores 4 --max-jobs 1 -L

# Android SDK licenses are accepted in this dedicated devShell only.
alvr-android-shell:
    nix develop .#alvr-android

prepare-alvr-android:
    nix develop .#alvr-android --command alvr-android prepare

# Compile and verify the Quest 2 APK; never install it or activate the system.
build-alvr-android:
    nix develop .#alvr-android --command alvr-android build

verify-alvr-android:
    nix develop .#alvr-android --command alvr-android verify

# Workspace regression tests; no SDK, device or signing key required.
test-alvr-android:
    nix build .#checks.x86_64-linux.alvr-android-workflow --no-link -L

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
  system-manager switch --flake .#devbox --sudo

build-vps:
  system-manager switch --flake .#gkzhb-vps --sudo

build-mido:
  system-manager switch --flake .#mido --sudo

# build standalone home-manager config
build-home user:
  home-manager switch --flake .#{{user}}

build-darwin:
  # nix run nix-darwin/master#darwin-rebuild -- switch
  darwin-rebuild switch --flake .#gkzhb-MBP

format:
  nix fmt

check-format:
  nix flake check

install-hooks:
  nix develop
