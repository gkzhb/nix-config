{ config, pkgs, ... }:

let
  user = "zhanghaibin.zhb";
  home = "/home/${user}";
  dataDir = "${home}/scripts/services/dolt";
  certificateDir = "/etc/letsencrypt/live/byte.gkzhb.top";
  serverConfig = (pkgs.formats.yaml { }).generate "dolt-server.yaml" {
    listener = {
      host = "0.0.0.0";
      port = 3307;
      socket = "/run/dolt/dolt.sock";
      tls_cert = "\${CREDENTIALS_DIRECTORY}/tls-cert";
      tls_key = "\${CREDENTIALS_DIRECTORY}/tls-key";
      require_secure_transport = true;
    };
    data_dir = dataDir;
    cfg_dir = "${dataDir}/.doltcfg";
  };
in
{
  sops = {
    defaultSopsFile = ../../../secrets/devbox-dolt.yaml;
    age.keyFile = "${home}/.config/sops/age/keys.txt";
    age.generateKey = false;
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];
    secrets.dolt-root-password = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "dolt.service" ];
    };
  };

  environment.systemPackages = [ pkgs.dolt ];
  # WorkingDirectory is entered before ExecStartPre. Prepare it as the user,
  # including first activation; privileged tmpfiles rejects the ownership
  # transition through devbox's symlinked HOME (/data00 -> /data00/home).
  systemd.services.dolt-data-directory = {
    description = "Prepare persistent Dolt data directory";
    unitConfig.RequiresMountsFor = [ dataDir ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = user;
      ExecStart = "${pkgs.coreutils}/bin/install -d -m 0700 ${dataDir}";
      UMask = "0077";
    };
  };
  systemd.services.dolt = {
    description = "Dolt SQL Server with authenticated TLS";
    wantedBy = [ "system-manager.target" ];
    # Home Manager must remove the legacy user unit before this server starts.
    after = [
      "dolt-data-directory.service"
      "sops-install-secrets.service"
      "home-manager-${user}.service"
    ];
    requires = [
      "dolt-data-directory.service"
      "sops-install-secrets.service"
      "home-manager-${user}.service"
    ];
    unitConfig.RequiresMountsFor = [
      dataDir
      certificateDir
    ];
    environment.HOME = home;
    serviceConfig = {
      Type = "simple";
      User = user;
      Group = user;
      WorkingDirectory = dataDir;
      RuntimeDirectory = "dolt";
      RuntimeDirectoryMode = "0700";
      # The system manager reads root-only originals, then makes private runtime
      # credentials accessible to User. Never widen Let's Encrypt permissions.
      LoadCredential = [
        "root-password:${config.sops.secrets.dolt-root-password.path}"
        "tls-cert:${certificateDir}/fullchain.pem"
        "tls-key:${certificateDir}/privkey.pem"
      ];
      ExecStartPre = "${pkgs.python3}/bin/python3 ${../../../scripts/dolt-prepare-root.py} ${pkgs.dolt}/bin/dolt";
      ExecStart = "${pkgs.dolt}/bin/dolt sql-server --config ${serverConfig} --skip-root-user-initialization";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "180s";
      TimeoutStopSec = "60s";
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
    };
  };

  # certbot-renew.service's deploy hook restarts an active Dolt after successful
  # renewal so its runtime credential snapshots contain the new cert/key.
}
