{
  config,
  pkgs,
  ...
}:

{
  systemd.services.frp = {
    description = "frp server service";
    wantedBy = [ "system-manager.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.frp}/bin/frps -c /etc/frp/frps.toml";
      Restart = "always";
    };
  };

  systemd.services.xray = {
    description = "xray proxy service";
    wantedBy = [ "system-manager.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xray}/bin/xray -config /etc/xray/config.json";
      Restart = "always";
    };
  };

  systemd.services.tailscaled = {
    description = "Tailscale node agent";
    wantedBy = [ "system-manager.target" ];
    after = [
      "network-pre.target"
      "NetworkManager.service"
      "systemd-resolved.service"
    ];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock $FLAGS";
      ExecStopPost = "${pkgs.tailscale}/bin/tailscaled --cleanup";
      Restart = "on-failure";
      RuntimeDirectory = "tailscale";
      RuntimeDirectoryMode = "0755";
      StateDirectory = "tailscale";
      StateDirectoryMode = "0700";
      CacheDirectory = "tailscale";
      CacheDirectoryMode = "0750";
    };
  };

  # docker compose stacks under /home/zhb/scripts/docker/<name>/
  # Managed via Type=oneshot + RemainAfterExit=yes so systemctl stop runs
  # `docker compose down` for a clean shutdown.
  systemd.services.docker-derper = {
    description = "Tailscale DERP server (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/derper";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  systemd.services.docker-pgsql = {
    description = "PostgreSQL + pgvector (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/pgsql";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.services.docker-mongodb = {
    description = "Standalone MongoDB (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/mongodb";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  systemd.services.docker-authentik = {
    description = "Authentik identity provider (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
      "docker-pgsql.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/authentik";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  systemd.services.docker-librechat = {
    description = "LibreChat AI chat frontend (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
      "docker-pgsql.service"
      "docker-mongodb.service"
      "docker-authentik.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/LibreChat";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  systemd.services.docker-bitwarden = {
    description = "Vaultwarden password manager (docker compose)";
    wantedBy = [ "system-manager.target" ];
    wants = [ "docker.service" ];
    after = [
      "network.target"
      "docker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      WorkingDirectory = "/home/zhb/scripts/docker/bitwarden";
      ExecStart = "docker compose up --wait --force-recreate";
      ExecStop = "docker compose down";
      TimeoutStartSec = "0";
      TimeoutStopSec = "5min";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

}
