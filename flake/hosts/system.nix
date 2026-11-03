{ inputs, ... }:
let
  inherit (inputs) system-manager sops-nix home-manager;
  inherit (import ../overlays.nix { inherit inputs; })
    edge-overlay
    llm-agents-overlay
    browseros-overlay
    ;
in
{
  flake.systemConfigs = {
    mido = system-manager.lib.makeSystemConfig {
      # Pass full package-set overlays directly: this avoids the recursive
      # `listOf anything` merge used by System Manager's nixpkgs.overlays option.
      overlays = [ edge-overlay ];
      modules = [
        { nixpkgs.overlays = [ llm-agents-overlay ]; }
        ../../hosts/mido/modules/default.nix
      ];
    };
    devbox = system-manager.lib.makeSystemConfig {
      overlays = [
        browseros-overlay
        edge-overlay
      ];
      modules = [
        { nixpkgs.overlays = [ llm-agents-overlay ]; }
        home-manager.nixosModules.home-manager
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ../../hosts/devbox/modules/default.nix
      ];
    };
    "gkzhb-vps" = system-manager.lib.makeSystemConfig {
      overlays = [ edge-overlay ];
      modules = [
        sops-nix.nixosModules.sops
        ../../hosts/gkzhb-vps/modules/default.nix
        ../../hosts/gkzhb-vps/modules/systemd.nix
        ../../hosts/gkzhb-vps/modules/vaultwarden.nix
        ../../hosts/gkzhb-vps/modules/telegraf.nix
      ];
    };
  };

}
