{ config, pkgs, ... }:
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
  };
}
