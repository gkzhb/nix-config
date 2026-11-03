# Evaluate through the real flake, without building or activating any system:
# nix eval --accept-flake-config --impure --json --expr \
#   'import ./scripts/tests/flake-output-shape.nix { flakeRef = toString ./.; }'
{ flakeRef }:
let
  flake = builtins.getFlake flakeRef;
  names = builtins.attrNames;
  mapAttrs = builtins.mapAttrs;
  developmentSystems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
  packageSystems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-linux"
  ];
  corePackages = [
    "aoci-code"
    "cccc-cli"
    "default"
    "knots"
    "mmx-cli"
  ];
  shape = {
    nixosConfigurations = names flake.nixosConfigurations;
    darwinConfigurations = names flake.darwinConfigurations;
    systemConfigs = names flake.systemConfigs;
    homeConfigurations = names flake.homeConfigurations;
    packages = mapAttrs (_: names) flake.packages;
    checks = mapAttrs (_: names) flake.checks;
    devShells = mapAttrs (_: names) flake.devShells;
    formatter = names flake.formatter;
  };
  expected = {
    nixosConfigurations = [
      "home-nixos"
      "zhb-nixos"
    ];
    darwinConfigurations = [ "gkzhb-MBP" ];
    systemConfigs = [
      "devbox"
      "gkzhb-vps"
      "mido"
    ];
    homeConfigurations = [ "zhb" ];
    packages = builtins.listToAttrs (
      map (system: {
        name = system;
        value = builtins.sort builtins.lessThan (
          corePackages ++ [ "new-api" ] ++ (if system == "x86_64-linux" then [ "browseros-neo" ] else [ ])
        );
      }) packageSystems
    );
    checks = builtins.listToAttrs (
      map (system: {
        name = system;
        value = [ "formatting" ];
      }) developmentSystems
    );
    devShells = builtins.listToAttrs (
      map (system: {
        name = system;
        value = [ "default" ];
      }) developmentSystems
    );
    formatter = developmentSystems;
  };
in
if shape == expected then
  shape
else
  throw "Flake output support matrix changed. Actual: ${builtins.toJSON shape}"
