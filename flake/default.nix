{ inputs, ... }:
{
  imports = [
    ./development.nix
    ./packages.nix
    ./hosts/nixos.nix
    ./hosts/system.nix
    ./hosts/home.nix
    ./hosts/darwin.nix
  ];

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  # Preserve the original package set for formatter, checks and devShells.
  perSystem = { system, ... }: {
    _module.args.pkgs = inputs.nixpkgs.legacyPackages.${system};
  };
}
