{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles;
  activeLinks = lib.filterAttrs (_: source: source != null);
  mkLinks = lib.mapAttrs (
    _: source: {
      source = config.lib.file.mkOutOfStoreSymlink "${cfg.root}/${source}";
    }
  );
  # Fish shares these directories with Home Manager, plugins and local files.
  fishFiles = [
    "fish_plugins"
    "completions/pnpm.fish"
    "functions/y.fish"
    "conf.d/brew.fish"
    "conf.d/claude.fish"
    "conf.d/common.fish"
    "conf.d/dotfiles.fish"
    "conf.d/emacs.fish"
    "conf.d/fish_prompt.fish"
    "conf.d/fish_user_key_bindings.fish"
    "conf.d/npm.fish"
    "conf.d/pnpm.fish"
    "conf.d/tuios.fish"
    "conf.d/z-aliases.fish"
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    "conf.d/notification.mac.fish"
    "conf.d/yabai.mac.fish"
  ];
  linkOption = description: {
    inherit description;
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = { };
  };
  allSources = lib.unique (
    builtins.attrValues (activeLinks cfg.configLinks) ++ builtins.attrValues (activeLinks cfg.homeLinks)
  );
in
{
  options.dotfiles = {
    enable = lib.mkEnableOption "editable dotfiles linked from a local Git checkout";
    root = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/nix-config/dotfiles";
      description = "Absolute runtime path to the dotfiles checkout, not a Nix path or store snapshot.";
    };
    configLinks = lib.mkOption (
      linkOption "XDG config target to checkout-relative source; null disables a mapping."
    );
    homeLinks = lib.mkOption (
      linkOption "HOME target to checkout-relative source; null disables a mapping."
    );
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.root && !(lib.hasPrefix builtins.storeDir cfg.root);
        message = "dotfiles.root must be an absolute path outside the Nix store.";
      }
    ];

    dotfiles.configLinks = lib.mapAttrs (_: lib.mkDefault) (
      lib.genAttrs [
        "alacritty"
        "coc"
        "doom"
        "git"
        "kitty"
        "lf"
        "nvim"
        "pip"
        "television"
        "tuios"
        "uv"
        "wezterm"
        "yazi"
      ] (name: ".config/${name}")
      // lib.genAttrs (map (name: "fish/${name}") fishFiles) (name: ".config/${name}")
      // {
        "herdr/config.toml" = ".config/herdr/config.toml";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        aerospace = ".config/aerospace";
      }
    );

    dotfiles.homeLinks = lib.mapAttrs (_: lib.mkDefault) (
      {
        ".gitconfig" = ".gitconfig";
        ".tmux.conf" = ".tmux.conf";
        ".tmux/onedark.conf" = ".tmux/onedark.conf";
        ".tmux/vim-tmux-navigator.conf" = ".tmux/vim-tmux-navigator.conf";
        "scripts/lf" = "scripts/lf";
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        ".hammerspoon" = ".config/hammerspoon";
        ".skhdrc" = ".skhdrc";
        ".yabairc" = ".yabairc";
        "scripts/yabai" = "scripts/yabai";
      }
    );

    xdg.configFile = mkLinks (activeLinks cfg.configLinks);
    home.file = mkLinks (activeLinks cfg.homeLinks);

    # Do not inspect the mutable checkout at evaluation time. Check all sources
    # before Home Manager can change links, without deleting conflicting targets.
    home.activation.checkDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      ${lib.concatMapStringsSep "\n" (source: ''
        if [ ! -e ${lib.escapeShellArg "${cfg.root}/${source}"} ]; then
          echo ${lib.escapeShellArg "Missing dotfiles source: ${cfg.root}/${source}. Clone/update the checkout before activating."} >&2
          exit 1
        fi
      '') allSources}
    '';

    # Override the old bare-repository aliases after conf.d has been sourced.
    programs.fish.interactiveShellInit = lib.mkAfter ''
      function cfg --description 'Git for the editable dotfiles checkout'
        command git -C ${lib.escapeShellArg cfg.root} $argv
      end
      function dv --description 'Edit the dotfiles checkout'
        command nvim ${lib.escapeShellArg cfg.root} $argv
      end
    '';
  };
}
