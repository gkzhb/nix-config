{ config, pkgs, ... }:

{
  # The host age identity is configured in vaultwarden.nix.
  sops.secrets.croc-relay-password = {
    sopsFile = ../../../secrets/gkzhb-vps-croc-relay.yaml;
    format = "yaml";
    mode = "0400";
  };
  sops.templates."croc-relay.env" = {
    mode = "0400";
    restartUnits = [ "croc-relay.service" ];
    content = ''
      CROC_PASS=${config.sops.placeholder.croc-relay-password}
    '';
  };

  systemd.services.croc-relay = {
    description = "Croc Relay Server";
    wantedBy = [ "system-manager.target" ];
    wants = [ "network-online.target" ];
    requires = [ "sops-install-secrets.service" ];
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.croc}/bin/croc relay --ports 9009,9010";
      EnvironmentFile = config.sops.templates."croc-relay.env".path;
      Restart = "always";
      RestartSec = "5s";
      DynamicUser = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      UMask = "0077";
    };
  };

  # The host firewall is managed by UFW, not System Manager.
  # Allow TCP 9009/9010 in UFW and any upstream firewall before use.
}
