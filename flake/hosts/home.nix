{ inputs, ... }:
let
  inherit (inputs) nixpkgs home-manager;
in
{
  flake.homeConfigurations = {
    "zhb" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit inputs;
      };
      modules = [ ../../hosts/gkzhb-vps/user.nix ];
    };
  };
}
