# Compatibility default: activate home-nixos (run with sudo as before).
build: (build-nixos "home-nixos")

# Build and activate a NixOS configuration from this repository.
[positional-arguments]
build-nixos host:
    nixos-rebuild switch --flake ".#$1" --accept-flake-config

# Build and activate a System Manager configuration.
[positional-arguments]
build-system-manager host:
    system-manager switch --flake ".#$1" --sudo --nix-option accept-flake-config true

# Build and activate a standalone Home Manager configuration (user/config key).
[positional-arguments]
build-home-manager host:
    home-manager switch --flake ".#$1" --option accept-flake-config true

# Build and activate nix-darwin, including its integrated Home Manager config.
[positional-arguments]
build-darwin host="gkzhb-MBP":
    darwin-rebuild switch --flake ".#$1" --option accept-flake-config true

# Build a package/check without activation; optional flags are passed to Nix.
[positional-arguments]
build-package target *flags:
    target="$1"; shift; nix build ".#$target" --accept-flake-config -L "$@"

build-zhb: (build-nixos "zhb-nixos")

build-devbox: (build-system-manager "devbox")

build-vps: (build-system-manager "gkzhb-vps")

build-mido: (build-system-manager "mido")

build-home user: (build-home-manager user)

# FSL-1.1-MIT is non-free; permission applies only to this invocation.
build-aoci-code:
    NIXPKGS_ALLOW_UNFREE=1 {{ quote(just_executable()) }} --justfile {{ quote(justfile()) }} build-package aoci-code --impure

# Build the pinned ALVR master snapshot without activating the system.
build-alvr: (build-package "alvr" "--cores" "4" "--max-jobs" "1")

# Android SDK licenses are accepted in this dedicated devShell only.
alvr-android-shell:
    nix develop .#alvr-android --accept-flake-config

prepare-alvr-android:
    nix develop .#alvr-android --accept-flake-config --command alvr-android prepare

# Compile and verify the Quest 2 APK; never install it or activate the system.
build-alvr-android:
    nix develop .#alvr-android --accept-flake-config --command alvr-android build

verify-alvr-android:
    nix develop .#alvr-android --accept-flake-config --command alvr-android verify

# Workspace regression tests; no SDK, device or signing key required.
test-alvr-android: (build-package "checks.x86_64-linux.alvr-android-workflow" "--no-link")

# update flake and package versions
# need to rebuild after running this
update:
    nix flake update --accept-flake-config

update-nix:
    nix flake update --accept-flake-config nixpkgs nix-ld sops-nix home-manager nix-darwin system-manager

create-age-key:
    mkdir -p ~/.config/sops/age
    age-keygen -o ~/.config/sops/age/keys.txt

# update secrets file after adding new hosts in .sops.yaml
update-secrets:
    sops updatekeys secrets/db.yaml

edit-secrets:
    sops secrets/db.yaml

# Test command routing with fake tools; no builds or system activation.
test-justfile:
    python3 scripts/tests/test-justfile.py

format:
    nix fmt --accept-flake-config

check-format:
    nix flake check --accept-flake-config

install-hooks:
    nix develop --accept-flake-config --command true
