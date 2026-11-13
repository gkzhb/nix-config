{ config, ... }:

{
  imports = [ ../../modules/home-manager/dotfiles.nix ];

  home = {
    username = "zhb";
    homeDirectory = "/home/zhb";
    stateVersion = "26.11";
  };

  dotfiles = {
    enable = true;
    root = "${config.home.homeDirectory}/nix-config/dotfiles";
    # CoC also stores installed extensions and mutable state here. Only its
    # snippets belong to dotfiles; leave the rest of this directory in HOME.
    configLinks = {
      coc = null;
      "coc/ultisnips" = ".config/coc/ultisnips";
    };
  };

  programs.home-manager.enable = true;
  programs.fish.enable = true;
}
