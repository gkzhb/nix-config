{ inputs, self, ... }:
let
  inherit (inputs) nix-darwin home-manager sops-nix;
  inherit (import ../overlays.nix { inherit inputs; }) llm-agents-overlay local-packages;
in
{
  flake.darwinConfigurations = {
    "gkzhb-MBP" = nix-darwin.lib.darwinSystem {
      modules = [
        {
          nixpkgs.overlays = [
            llm-agents-overlay
            local-packages
          ];
        }
        ../../hosts/gkzhb-mbp/configuration.nix
        sops-nix.darwinModules.sops
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.bytedance = ../../hosts/gkzhb-mbp/user.nix;

          # Optionally, use home-manager.extraSpecialArgs to pass
          # arguments to home.nix
        }
      ];
      specialArgs = {
        inherit self; # codebase-memory-mcp;
      };
    };
  };
}
