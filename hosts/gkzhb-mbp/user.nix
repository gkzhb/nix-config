{
  config,
  pkgs,
  darwinConfig,
  ...
}:

{
  imports = [ ../../modules/home-manager/dotfiles.nix ];

  dotfiles = {
    enable = true;
    root = "${config.home.homeDirectory}/nix-config/dotfiles";
  };

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    username = "bytedance";
    sessionVariables.XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "25.11";
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;

    fish = {
      enable = true;
      package = darwinConfig.programs.fish.package;
      shellInit = ''
        set -gx LESSCHARSET utf-8
      '';
    };

    neovim = {
      enable = false;
      withPython3 = true;
      extraPython3Packages =
        ps: with ps; [
          pynvim
          # other required python packages
          ruff
          ty
        ];
    };
  };
}
