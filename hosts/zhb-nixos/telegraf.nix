{ config, lib, ... }:

let
  # Collect independently at each resolution; output flush intervals alone do not
  # change the sampling rate or downsample metrics.
  tiers = [
    {
      bucket = "telegraf";
      interval = "10m";
    }
    {
      bucket = "telegraf_short";
      interval = "20s";
    }
  ];
  systemInputs = {
    cpu = {
      percpu = true;
      totalcpu = true;
      collect_cpu_time = false;
      report_active = false;
    };
    mem = { };
    disk = {
      ignore_fs = [
        "tmpfs"
        "devtmpfs"
        "devfs"
        "overlay"
        "squashfs"
        "nsfs"
      ];
    };
    diskio = { };
    net = { };
    system = { };
    processes = { };
    nvidia_smi = {
      bin_path = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-smi";
      timeout = "10s";
    };
  };
in
{
  sops.templates."telegraf-influxdb2.env" = {
    owner = "telegraf";
    group = "telegraf";
    mode = "0400";
    restartUnits = [ "telegraf.service" ];
    content = ''
      INFLUX_TOKEN=${config.sops.placeholder."influxdb2/zhb_nixos_token"}
    '';
  };

  services.telegraf = {
    enable = true;
    environmentFiles = [ config.sops.templates."telegraf-influxdb2.env".path ];
    extraConfig = {
      agent = {
        interval = "20s";
        round_interval = true;
        metric_batch_size = 1000;
        metric_buffer_limit = 10000;
        flush_interval = "20s";
        hostname = config.networking.hostName;
      };
      outputs.influxdb_v2 = map (tier: {
        # Reach home-nixos over the private network; do not expose port 8086 publicly.
        urls = [ "http://home.h.gkzhb.top:8086" ];
        token = "$INFLUX_TOKEN";
        organization = "home";
        bucket = tier.bucket;
        flush_interval = tier.interval;
        tagpass.retention_tier = [ tier.bucket ];
        # Routing only: do not persist this internal tag in InfluxDB.
        tagexclude = [ "retention_tier" ];
      }) tiers;
      inputs = lib.mapAttrs (
        _: settings:
        map (
          tier:
          settings
          // {
            interval = tier.interval;
            tags.retention_tier = tier.bucket;
          }
        ) tiers
      ) systemInputs;
    };
  };
}
