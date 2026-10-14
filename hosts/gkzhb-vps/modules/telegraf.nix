{ config, pkgs, ... }:

let
  # System Manager does not import the NixOS Telegraf service module.
  configFile = (pkgs.formats.toml { }).generate "telegraf.toml" {
    agent = {
      interval = "1m";
      round_interval = true;
      metric_batch_size = 1000;
      metric_buffer_limit = 10000;
      flush_interval = "1m";
      hostname = "gkzhb-vps";
    };
    outputs.influxdb_v2 = {
      # Private Tailscale network only; no public InfluxDB port is needed.
      urls = [ "http://home.h.gkzhb.top:8086" ];
      token = "$INFLUX_TOKEN";
      organization = "home";
      bucket = "telegraf_short";
      timeout = "10s";
    };
    inputs = {
      cpu = {
        percpu = false;
        totalcpu = true;
        collect_cpu_time = false;
        report_active = false;
      };
      mem = { };
      swap = { };
      disk = {
        ignore_fs = [
          "tmpfs"
          "devtmpfs"
          "devfs"
          "overlay"
          "squashfs"
          "nsfs"
          "autofs"
        ];
      };
      # Exclude loop devices and ephemeral container network interfaces.
      diskio.devices = [
        "vd*"
        "sd*"
        "nvme*"
      ];
      net.interfaces = [
        "eth*"
        "en*"
        "tailscale*"
      ];
      system = { };
    };
  };
in
{
  # A separate file/token avoids granting this host access to other secrets.
  # The age identity is configured by vaultwarden.nix for this same host.
  sops.secrets."influxdb2/gkzhb_vps_token" = {
    sopsFile = ../../../secrets/gkzhb-vps-telegraf.yaml;
    format = "yaml";
    mode = "0400";
  };
  sops.templates."telegraf-influxdb2.env" = {
    mode = "0400";
    restartUnits = [ "telegraf.service" ];
    content = ''
      INFLUX_TOKEN=${config.sops.placeholder."influxdb2/gkzhb_vps_token"}
    '';
  };

  users.groups.telegraf = { };
  users.users.telegraf = {
    isSystemUser = true;
    group = "telegraf";
    description = "Telegraf monitoring agent";
  };

  systemd.services.telegraf = {
    description = "Telegraf system overview metrics to home-nixos";
    wantedBy = [ "system-manager.target" ];
    wants = [ "network-online.target" ];
    requires = [ "sops-install-secrets.service" ];
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    serviceConfig = {
      Type = "simple";
      User = "telegraf";
      Group = "telegraf";
      EnvironmentFile = config.sops.templates."telegraf-influxdb2.env".path;
      ExecStart = "${pkgs.telegraf}/bin/telegraf --config ${configFile}";
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      # Keep host mount statistics visible to the disk input.
      ProtectHome = "read-only";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
    };
  };
}
