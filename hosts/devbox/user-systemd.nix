{
  config,
  pkgs,
  ...
}:

{
  # systemd.user.services.openclaw-gateway = {
  #   Unit = {
  #     Description = "OpenClaw Gateway";
  #     After = [ "network-online.target" ];
  #     Wants = [ "network-online.target" ];
  #   };
  #   Install = {
  #     WantedBy = [ "default.target" ];
  #   };
  #   Service = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.fish}/bin/fish -l %h/openclaw/run.fish";
  #     Restart = "always";
  #     RestartSec = "5";
  #     KillMode = "process";
  #     Environment = [
  #       "HOME=%h"
  #       "TMPDIR=/tmp"
  #       "OPENCLAW_GATEWAY_PORT=18789"
  #       "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
  #       "OPENCLAW_SERVICE_MARKER=openclaw"
  #       "OPENCLAW_SERVICE_KIND=gateway"
  #       "OPENCLAW_SERVICE_VERSION=2026.3.2"
  #     ];
  #   };
  # };
  systemd.user.services.tmux-mcp = {
    Unit = {
      Description = "tmux-mcp service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/tmux/tmux-mcp.fish";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.web-mcp = {
    Unit = {
      Description = "web-mcp service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/tmux/web-mcp.fish";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.graphiti-mcp = {
    Unit = {
      Description = "graphiti-mcp service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/gitrep/graphiti/mcp_server/run.fish";
      WorkingDirectory = "%h/gitrep/graphiti/mcp_server";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  systemd.user.services.opencode = {
    Unit = {
      Description = "opencode service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/tmux/vibe.fish";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.nodered = {
    Unit = {
      Description = "nodered service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/docker/nodered/run.fish";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.openwebui = {
    Unit = {
      Description = "open webui service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/docker/open-webui/run.fish";
      WorkingDirectory = "%h/scripts/docker/open-webui";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.brave = {
    Unit = {
      Description = "brave browser service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -S /tmp/.X11-unix/X1 ]; do sleep 1; done'";
      ExecStart = "${pkgs.brave}/bin/brave --remote-debugging-port=9222 --user-data-dir=%h/.local/share/brave-mcp";
      Environment = [
        "DISPLAY=:1"
        "XAUTHORITY=%h/.Xauthority"
      ];
      Restart = "on-failure";
      RestartSec = "10";
    };
  };
  systemd.user.services.quartz = {
    Unit = {
      Description = "quartz service";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/gitrep/quartz/run.fish";
      WorkingDirectory = "%h/gitrep/quartz";
      Restart = "on-failure";
      RestartSec = "10";
    };
  };

  # Code-server 服务配置
  systemd.user.services.code-server = {
    Unit = {
      Description = "VS Code Server";
      After = [ "network.target" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.code-server}/bin/code-server --disable-telemetry";
      Restart = "on-failure";
      RestartSec = "10";
      Environment = [
        "PATH=${pkgs.git}/bin:${pkgs.nodejs}/bin"
      ];
    };
  };
}
