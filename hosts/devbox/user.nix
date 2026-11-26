{
  config,
  pkgs,
  ...
}:

{
  dotfiles = {
    enable = true;
    root = "${config.home.homeDirectory}/nix-config/dotfiles";
    pi = {
      enable = true;
      modelProfile = "byte";
      defaultProvider = "byte";
      defaultModel = "gpt-6.1-sol";
      workerModel = "byte/ds-v4-flash";
      enabledModels = [
        "newapi/**"
        "magpie/**"
        "byte/**"
      ];
    };
  };

  home = {
    username = "zhanghaibin.zhb";
    homeDirectory = "/home/zhanghaibin.zhb";
    stateVersion = "25.11";
    packages = with pkgs; [ dolt ];
    sessionPath = [
      "$HOME/.nix-profile/bin"
    ];
  };
  programs.home-manager.enable = true;
  programs.fish.enable = true;
  # programs.neovim = {
  #   enable = true;
  #   defaultEditor = true;
  #   withNodeJs = true;
  #   withPython3 = true;
  #   vimAlias = true;
  #   viAlias = true;
  #   extraPython3Packages =
  #     ps: with ps; [
  #       pynvim
  #       # other required python packages
  #     ];
  # };
  imports = [
    ../../modules/home-manager/dotfiles.nix
    ./user-systemd.nix
    ./botmux-fonts.nix
  ];
}
