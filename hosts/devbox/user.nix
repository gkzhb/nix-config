{
  config,
  pkgs,
  inputs,
  ...
}:

{
  dotfiles = {
    enable = true;
    root = "${config.home.homeDirectory}/nix-config/dotfiles";
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
  sops = {
    defaultSopsFile = ../../secrets/devbox-dolt.yaml;
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    age.generateKey = false;
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];
    secrets.dolt-root-password.mode = "0400";
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
    inputs.sops-nix.homeManagerModules.sops
    ../../modules/home-manager/dotfiles.nix
    ./user-systemd.nix
  ];
}
