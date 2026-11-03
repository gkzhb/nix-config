{ inputs, ... }:
let
  inherit (inputs) nixpkgs home-manager;
  inherit (import ../overlays.nix { inherit inputs; }) llm-agents-overlay;
in
{
  flake.homeConfigurations = {
    # for devbox user
    "zhanghaibin.zhb" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit inputs;
      };
      modules = [
        { nixpkgs.overlays = [ llm-agents-overlay ]; }
        ../../hosts/devbox/user.nix
      ];
    };

    "zhb" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = {
        inherit inputs;
      };
      modules = [ ../../hosts/gkzhb-vps/user.nix ];
    };
  };
}
