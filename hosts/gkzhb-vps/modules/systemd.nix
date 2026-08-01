{
  config,
  pkgs,
  lib,
  ...
}:

let
  # system-manager 默认 PATH 不含 curl/docker 等系统二进制;
  # 这里覆盖为系统 PATH + system-manager 自己的 sw/bin
  systemPath = "PATH=/run/wrappers/bin:/run/system-manager/sw/bin:/usr/local/bin:/usr/bin:/bin";
in
{
  systemd.services = {
    nginx.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "";
      Group = lib.mkForce "";
      ReadOnlyPaths = [
        "/etc/letsencrypt"
      ];
      ProtectSystem = lib.mkForce "false";
      # ProtectHome = lib.mkForce false;
      # NoNewPrivileges = lib.mkForce false;
      # PrivateUsers = lib.mkForce false;
      PrivateTmp = lib.mkForce false;
      SystemCallFilter = lib.mkForce [ "" ];
      SystemCallArchitectures = lib.mkForce "";
      SystemCallErrorNumber = lib.mkForce "";
      CapabilityBoundingSet = lib.mkForce [
        "CAP_NET_BIND_SERVICE"
        "CAP_SETUID"
        "CAP_SETGID"
        "CAP_CHOWN"
      ];
      AmbientCapabilities = lib.mkForce [
        ""
      ];
    };
    frp = {
      description = "frp server service";
      wantedBy = [ "system-manager.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.frp}/bin/frps -c /etc/frp/frps.toml";
        Restart = "always";
      };
    };

    xray = {
      description = "xray proxy service";
      wantedBy = [ "system-manager.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.xray}/bin/xray -config /etc/xray/config.json";
        Restart = "always";
      };
    };

    tailscaled = {
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
    docker-derper = {
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

    docker-pgsql = {
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
    docker-mongodb = {
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

    docker-authentik = {
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

    docker-librechat = {
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

    docker-bitwarden = {
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

    # cronjob services
    # Runs /home/zhb/scripts/refresh-codex.sh on the schedule equivalent to
    # `0 1,10,15,20 * * *` — daily at 01:00, 10:00, 15:00, 20:00.
    refresh-codex = {
      description = "Refresh codex";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/home/zhb/scripts/refresh-codex.sh";
        Environment = systemPath;
      };
    };

    certbot-renew = {
      description = "Renew Let's Encrypt certificates";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/home/zhb/scripts/certbot/renew.sh";
        Environment = systemPath;
      };
    };
  };

  systemd.timers = {
    refresh-codex = {
      description = "Trigger refresh-codex service at 01:00, 10:00, 15:00, 20:00 daily";
      wantedBy = [ "system-manager.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 01,10,15,20:00:00";
        Persistent = true;
        Unit = "refresh-codex.service";
      };
    };

    certbot-renew = {
      description = "Trigger certbot-renew service at 03:00 on the 15th of every 2nd month";
      wantedBy = [ "system-manager.target" ];
      timerConfig = {
        OnCalendar = "*-02,04,06,08,10,12-15 03:00:00";
        Persistent = true;
        Unit = "certbot-renew.service";
      };
    };
  };

}
