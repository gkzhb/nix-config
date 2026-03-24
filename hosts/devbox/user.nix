{ config, pkgs, ... }:

{
  home = {
    username = "zhanghaibin.zhb";
    homeDirectory = "/home/zhanghaibin.zhb";
    stateVersion = "25.11";
    packages = with pkgs; [ ];
  };
  programs.home-manager.enable = true;
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    withPython3 = true;
    vimAlias = true;
    extraPython3Packages =
      ps: with ps; [
        pynvim
        # other required python packages
      ];
  };
  imports = [
    ./user-systemd.nix
  ];
}
