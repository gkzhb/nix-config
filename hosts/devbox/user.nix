{ config, pkgs, ... }:

{
  home = {
    username = "zhanghaibin.zhb";
    homeDirectory = "/home/zhanghaibin.zhb";
    stateVersion = "25.11";
    packages = with pkgs; [ ];
  };
  programs.home-manager.enable = true;
  imports = [
    ./user-systemd.nix
  ];
}
