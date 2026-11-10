{ pkgs, ... }:

let
  redisConfig = pkgs.writeText "redis.conf" ''
    # Shared by local applications; never expose unauthenticated Redis remotely.
    bind 127.0.0.1
    port 6379
    protected-mode yes
    daemonize no
    supervised systemd
    dir .
    save ""
    appendonly yes
    appendfsync everysec
  '';
in
{
  # System Manager does not import NixOS's services.redis module.
  # Keep this host service independent of any particular application/user.
  environment.systemPackages = [ pkgs.redis ];
  systemd.services.redis = {
    description = "Shared local Redis server";
    wantedBy = [ "system-manager.target" ];
    after = [ "network.target" ];
    # Nix glibc must not rely on the host's locale archive. C.UTF-8 is built in.
    environment = {
      LANG = "C.UTF-8";
      LC_ALL = "C.UTF-8";
    };
    serviceConfig = {
      Type = "notify";
      NotifyAccess = "main";
      ExecStart = "${pkgs.redis}/bin/redis-server ${redisConfig}";
      DynamicUser = true;
      StateDirectory = "redis";
      StateDirectoryMode = "0700";
      WorkingDirectory = "/var/lib/redis";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictSUIDSGID = true;
    };
  };

  # The distro/host owns firewall rules. No port-opening rules are added here.
  # Loopback binding is not isolation between local users or applications.
}
