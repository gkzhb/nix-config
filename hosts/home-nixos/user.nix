{ config, pkgs, ... }:
let
  openclawPkg = pkgs.llm-agents.openclaw;
  openclawVersion = openclawPkg.version;
in
{
  home = {
    username = "zhb";
    homeDirectory = "/home/zhb";
    stateVersion = "25.11";
    packages = [ ];
  };
  programs.home-manager.enable = true;

  systemd.user.services = {
    opencode = {
      Unit = {
        Description = "OpenCode Web UI CodeNomad";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.fish}/bin/fish -c %h/scripts/services/opencode/run.fish";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    nanobot = {
      Unit = {
        Description = "nanobot";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.fish}/bin/fish -c %h/scripts/services/nanobot/run.fish";
        WorkingDirectory = "%h/scripts/services/nanobot";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    litellm = {
      Unit = {
        Description = "litellm proxy";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.fish}/bin/fish -c %h/scripts/services/litellm/run.fish";
        WorkingDirectory = "%h/scripts/services/litellm";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    web-mcp = {
      Unit = {
        Description = "web mcp server";
        After = [ "network.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.fish}/bin/fish -c %h/scripts/services/web-mcp/run.fish";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    openclaw-gateway = {
      Unit = {
        Description = "OpenClaw Gateway (v${openclawVersion})";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.nodejs}/bin/node ${openclawPkg}/lib/openclaw/dist/entry.js gateway --port 18789";
        Restart = "always";
        RestartSec = 5;
        KillMode = "process";
        Environment = [
          "HOME=/home/zhb"
          "OPENCLAW_GATEWAY_PORT=18789"
          "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
          "OPENCLAW_SERVICE_MARKER=openclaw"
          "OPENCLAW_SERVICE_KIND=gateway"
          "OPENCLAW_SERVICE_VERSION=${openclawVersion}"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
