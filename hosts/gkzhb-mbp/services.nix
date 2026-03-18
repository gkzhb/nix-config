{ pkgs, self, ... }:
{
  system.primaryUser = "bytedance";

  launchd.user.agents = {
    opencode = {
      command = "${pkgs.fish}/bin/fish -l /Users/bytedance/scripts/mcps/codenomad.fish";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
}
