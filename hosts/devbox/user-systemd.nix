{
  config,
  pkgs,
  ...
}:

let
  new-api = pkgs.callPackage ../../packages/new-api.nix { };
in
{
  systemd.user.services.dsh-web = {
    Unit = {
      Description = "DeepSeek Harness web service";
      # Stop the legacy launcher before taking over its listener.
      Conflicts = [ "dsh.service" ];
      After = [
        "network.target"
        "dsh.service"
      ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.edge.deepseek-harness}/bin/dsh web --port 3080 --host 127.0.0.1 --trusted-host dsh.byte.gkzhb.top --no-open";
      WorkingDirectory = "%h";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
  systemd.user.services.newapi = {
    # Redis is a system service: user-unit After/Wants cannot order it.
    # Its startup PING and Restart=on-failure retry if Redis is not ready.
    Unit.Description = "New API LLM gateway";
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${new-api}/bin/new-api --port 3000 --log-dir ./logs";
      WorkingDirectory = "%h/scripts/services/newapi";
      Environment = [
        "REDIS_CONN_STRING=redis://127.0.0.1:6379/0"
        "SQLITE_PATH=one-api.db?_pragma=busy_timeout(30000)&_pragma=journal_mode(WAL)&_txlock=immediate"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
    };
  };

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
  systemd.user.services.figma-mcp = {
    Unit = {
      Description = "Figma MCP service";
      After = [ "network.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fish}/bin/fish -l %h/scripts/services/figma/figma-mcp.fish";
      WorkingDirectory = "%h/scripts/services/figma";
      Environment = [ "PATH=${pkgs.nodejs}/bin:/run/system-manager/sw/bin:/usr/bin:/bin" ];
      Restart = "on-failure";
      RestartSec = "10s";
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
  # systemd.user.services.brave = {
  #   Unit = {
  #     Description = "brave browser service";
  #     After = [ "network.target" ];
  #   };
  #   Install = {
  #     WantedBy = [ "default.target" ];
  #   };
  #   Service = {
  #     Type = "simple";
  #     ExecStartPre = "${pkgs.bash}/bin/bash -c 'until [ -S /tmp/.X11-unix/X1 ]; do sleep 1; done'";
  #     ExecStart = "${pkgs.brave}/bin/brave --remote-debugging-port=9222 --user-data-dir=%h/.local/share/brave-mcp";
  #     Environment = [
  #       "DISPLAY=:1"
  #       "XAUTHORITY=%h/.Xauthority"
  #     ];
  #     Restart = "on-failure";
  #     RestartSec = "10";
  #   };
  # };
  # systemd.user.services.quartz = {
  #   Unit = {
  #     Description = "quartz service";
  #     After = [ "network.target" ];
  #   };
  #   Install = {
  #     WantedBy = [ "default.target" ];
  #   };
  #   Service = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.fish}/bin/fish -l %h/gitrep/quartz/run.fish";
  #     WorkingDirectory = "%h/gitrep/quartz";
  #     Restart = "on-failure";
  #     RestartSec = "10";
  #   };
  # };

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
