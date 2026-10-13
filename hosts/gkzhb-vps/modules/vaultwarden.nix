{ config, pkgs, ... }:

{
  # System Manager's sops-nix compatibility layer uses systemd activation.
  # Only encrypted JSON is included in the store; decrypt using a dedicated
  # machine age identity, never the SSH host key.
  sops = {
    defaultSopsFile = ../../../secrets/gkzhb-vps-vaultwarden.json;
    defaultSopsFormat = "json";
    age = {
      keyFile = "/home/zhb/.config/sops/age/keys.txt";
      generateKey = false;
      sshKeyPaths = [ ];
    };
    gnupg.sshKeyPaths = [ ];
    secrets.vaultwarden-config = {
      key = "";
      owner = "vaultwarden";
      group = "vaultwarden";
      mode = "0400";
      restartUnits = [ "vaultwarden.service" ];
    };
  };

  users.groups.vaultwarden = { };
  users.users.vaultwarden = {
    isSystemUser = true;
    group = "vaultwarden";
    home = "/var/lib/vaultwarden";
  };

  environment.systemPackages = [ pkgs.vaultwarden ];

  systemd.services.vaultwarden = {
    description = "Vaultwarden password manager";
    wantedBy = [ "system-manager.target" ];
    wants = [ "network-online.target" ];
    requires = [ "sops-install-secrets.service" ];
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    environment = {
      DATA_FOLDER = "/var/lib/vaultwarden";
      # Keep admin/SMTP settings out of the mutable data directory and store.
      CONFIG_FILE = config.sops.secrets.vaultwarden-config.path;
      WEB_VAULT_FOLDER = "${pkgs.vaultwarden.webvault}/share/vaultwarden/vault";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = "8087";
      DOMAIN = "https://passwd.gkzhb.top";
      SIGNUPS_ALLOWED = "false";
      WEB_VAULT_ENABLED = "true";
    };
    serviceConfig = {
      Type = "simple";
      User = "vaultwarden";
      Group = "vaultwarden";
      ExecStart = "${pkgs.vaultwarden}/bin/vaultwarden";
      WorkingDirectory = "/var/lib/vaultwarden";
      StateDirectory = "vaultwarden";
      StateDirectoryMode = "0700";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      # /admin configuration writes are deliberately disabled: edit the SOPS
      # file and reactivate instead, rather than storing secrets in plaintext.
    };
  };
}
