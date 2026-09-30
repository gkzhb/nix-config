{ pkgs, self, ... }:
{
  system.primaryUser = "bytedance";

  launchd.user.agents = {
    dsh = {
      command = "${pkgs.fish}/bin/fish -l /Users/bytedance/scripts/mcps/dsh.fish";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
  launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables = {
    HTTP_PROXY = "http://localhost:10881";
    HTTPS_PROXY = "http://localhost:10881";
    NO_PROXY = "localhost,127.0.0.1";
  };
}
