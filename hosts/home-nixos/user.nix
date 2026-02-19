{ config, pkgs, ... }:
{
  home = {
    username = "zhb";
    homeDirectory = "/home/zhb";
    stateVersion = "25.11";
    packages = [ ];
  };
  programs.home-manager.enable = true;
}
