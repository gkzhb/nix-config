{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles;
  pi = cfg.pi;
  piSharedSettings = ".pi/agent/settings.shared.json";
  piSettings = ".pi/agent/settings.json";
  piSettingsPath = lib.escapeShellArg "${config.home.homeDirectory}/${piSettings}";
  piSyncSettings = pkgs.writeShellScriptBin "pi-sync-settings" ''
    exec ${lib.getExe pkgs.python3} ${../../scripts/pi-sync-settings.py} \
      --settings ${piSettingsPath} \
      --shared ${lib.escapeShellArg "${cfg.root}/${piSharedSettings}"} \
      --overrides ${
        lib.escapeShellArg (builtins.toJSON { inherit (pi) defaultProvider defaultModel enabledModels; })
      } \
      "$@"
  '';
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
    "functions/tv-worktree.fish"
    "functions/tvn.fish"
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
  # Keep credentials, sessions and installed packages local. Link only selected
  # immediate children of the Pi agent directory, without splitting directories.
  # pi-stamp rejects symlinked settings; leave its optional config local.
  piEntries = [
    "settings.json"
    "models.json"
    "hud-footer.json"
    "extensions"
    "system-prompts"
    "shepherdr"
  ];
  linkOption = description: {
    inherit description;
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = { };
  };
  allSources = lib.unique (
    builtins.attrValues (activeLinks cfg.configLinks)
    ++ builtins.attrValues (activeLinks cfg.homeLinks)
    ++ lib.optional pi.enable piSharedSettings
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
    pi = {
      enable = lib.mkEnableOption "Pi model profiles and activation-time sync of writable local settings";
      modelProfile = lib.mkOption {
        type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9_-]*";
        description = "Name of a complete JSON model catalog in .pi/agent/model-profiles in the checkout.";
      };
      defaultProvider = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Default Pi provider applied by pi-sync-settings.";
      };
      defaultModel = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Default Pi model ID within the provider, applied by pi-sync-settings.";
      };
      enabledModels = lib.mkOption {
        type = lib.types.listOf lib.types.nonEmptyStr;
        default = [ ];
        description = "Pi startup and cycling model patterns applied by pi-sync-settings; empty means no scope.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.root && !(lib.hasPrefix builtins.storeDir cfg.root);
        message = "dotfiles.root must be an absolute path outside the Nix store.";
      }
    ]
    ++ lib.optional pi.enable {
      assertion = !(config.home.file ? ${piSettings});
      message = "dotfiles.pi requires settings.json to be a writable local file, not managed by home.file.";
    };

    home.packages = lib.optional pi.enable piSyncSettings;

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

    dotfiles.homeLinks =
      lib.mapAttrs (_: lib.mkDefault) (
        {
          ".gitconfig" = ".gitconfig";
          ".tmux.conf" = ".tmux.conf";
          ".tmux/onedark.conf" = ".tmux/onedark.conf";
          ".tmux/vim-tmux-navigator.conf" = ".tmux/vim-tmux-navigator.conf";
          "scripts/lf" = "scripts/lf";
        }
        // lib.genAttrs (map (name: ".pi/agent/${name}") piEntries) (name: name)
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          ".hammerspoon" = ".config/hammerspoon";
          ".skhdrc" = ".skhdrc";
          ".yabairc" = ".yabairc";
          "scripts/yabai" = "scripts/yabai";
        }
      )
      // lib.optionalAttrs pi.enable {
        ${piSettings} = null;
        ".pi/agent/models.json" = ".pi/agent/model-profiles/${pi.modelProfile}.json";
      };

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

    # The previous generation's source remains readable after linkGeneration
    # removes the old HOME symlink. Never adopt an unrelated symlink.
    home.activation.checkPiSettings = lib.mkIf pi.enable (
      lib.hm.dag.entryBetween [ "writeBoundary" ] [ "checkDotfiles" ] ''
        piSettingsSeed=()
        if [[ -L ${piSettingsPath} && -v oldGenPath && -d "$oldGenPath/home-files" ]]; then
          piOldSettings="$(readlink -e "$oldGenPath/home-files")/${piSettings}"
          if [[ "$(readlink -- ${piSettingsPath})" == "$piOldSettings" ]]; then
            piSettingsSeed=(--from "$piOldSettings")
          fi
        fi
        ${lib.getExe piSyncSettings} --check "''${piSettingsSeed[@]}"
      ''
    );
    home.activation.syncPiSettings = lib.mkIf pi.enable (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${lib.getExe piSyncSettings} "''${piSettingsSeed[@]}"
      ''
    );

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
