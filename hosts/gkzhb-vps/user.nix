{ config, pkgs, ... }:

{
  home = {
    username = "zhb";
    homeDirectory = "/home/zhb";
    stateVersion = "25.11";
    packages = with pkgs; [ ];
  };
  programs.home-manager.enable = true;
  imports = [
    # ./user-systemd.nix
  ];
}
