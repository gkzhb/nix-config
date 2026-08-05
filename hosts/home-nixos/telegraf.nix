{
  config,
  pkgs,
  ...
}:

{
  services.telegraf = {
    enable = true;
    environmentFiles = [ config.sops.templates."telegraf-influxdb2.env".path ];
    extraConfig = {
      agent = {
        # Collect regular system metrics once per minute.
        interval = "1m";
        round_interval = true;
        metric_batch_size = 1000;
        metric_buffer_limit = 10000;
        flush_interval = "10s";
        hostname = "home-nixos";
      };
      outputs.influxdb_v2 = {
        urls = [ "http://127.0.0.1:8086" ];
        token = "$INFLUX_TOKEN";
        organization = "home";
        bucket = "telegraf";
      };
      inputs = {
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
        prometheus = {
          urls = [ "http://127.0.0.1:8756/metrics" ];
          interval = "1m";
        };
        processes = { };
        mqtt_consumer = {
          servers = [ "tcp://100.64.0.15:1883" ];
          topics = [ "device/+/battery" ];
          topic_tag = "mqtt_topic";
          data_format = "json";
        };
        exec = [
          {
            commands = [ "${pkgs.nodejs_24}/bin/node ${../../scripts/newapi-usage.ts}" ];
            timeout = "30s";
            interval = "15m";
            data_format = "influx";
          }
          {
            commands = [ "${pkgs.nodejs_24}/bin/node ${../../scripts/minimax-token-plan-usage.ts}" ];
            timeout = "30s";
            interval = "15m";
            data_format = "influx";
          }
          {
            commands = [ "${pkgs.nodejs_24}/bin/node ${../../scripts/codex-subscription-usage.ts}" ];
            timeout = "30s";
            interval = "15m";
            data_format = "influx";
          }
        ];
      };
    };
  };
}
