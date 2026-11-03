{
  inputs,
  lib,
  getSystem,
  ...
}:
let
  inherit (import ./overlays.nix { inherit inputs; }) llm-agents-overlay local-packages;
  packageSystems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];
in
{
  # flake-parts normally transposes packages for every `systems` entry. Keep
  # the original package support matrix: Intel macOS only has development outputs.
  flake.packages = lib.mkForce (lib.genAttrs packageSystems (system: (getSystem system).packages));

  perSystem =
    { system, ... }:
    let
      # Do not replace perSystem.pkgs: development tools retain legacyPackages,
      # while exported packages keep their existing overlays and license policy.
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: lib.getName pkg == "browseros-neo";
        overlays = [
          llm-agents-overlay
          local-packages
        ];
      };
    in
    {
      packages = lib.optionalAttrs (builtins.elem system packageSystems) (
        {
          inherit (pkgs)
            mmx-cli
            knots
            cccc-cli
            aoci-code
            ;
          default = pkgs.mmx-cli;
        }
        // lib.optionalAttrs (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.new-api) {
          inherit (pkgs) new-api;
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          inherit (pkgs) browseros-neo;
        }
      );
    };
}
