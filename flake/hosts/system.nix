{ inputs, ... }:
let
  inherit (inputs) system-manager sops-nix;
  inherit (import ../overlays.nix { inherit inputs; }) llm-agents-overlay browseros-overlay;
in
{
  flake.systemConfigs = {
    mido = system-manager.lib.makeSystemConfig {
      modules = [
        { nixpkgs.overlays = [ llm-agents-overlay ]; }
        ../../hosts/mido/modules/default.nix
      ];
    };
    devbox = system-manager.lib.makeSystemConfig {
      overlays = [ browseros-overlay ];
      modules = [
        { nixpkgs.overlays = [ llm-agents-overlay ]; }
        ../../hosts/devbox/modules/default.nix
      ];
    };
    "gkzhb-vps" = system-manager.lib.makeSystemConfig {
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
