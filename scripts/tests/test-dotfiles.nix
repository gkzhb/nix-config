# Pure module evaluation only; does not build packages or activate HOME.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-dotfiles.nix
let
  flake = builtins.getFlake (toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  mkHome =
    system: modules:
    flake.inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
      inherit modules;
    };
  common = {
    imports = [ ../../modules/home-manager/dotfiles.nix ];
    home = {
      username = "dotfiles-test";
      homeDirectory = "/tmp/dotfiles-test";
      stateVersion = "25.11";
    };
    dotfiles = {
      enable = true;
      root = "/tmp/editable-dotfiles";
    };
  };
  darwin = mkHome "aarch64-darwin" [
    common
    { programs.fish.enable = true; }
  ];
  linux = mkHome "x86_64-linux" [ common ];
  overridden = mkHome "aarch64-darwin" [
    common
    {
      dotfiles.configLinks.kitty = lib.mkForce null;
      dotfiles.configLinks.nvim = ".config/custom-nvim";
      dotfiles.homeLinks.".pi/agent/settings.json" = lib.mkForce null;
    }
  ];
  disabled = mkHome "aarch64-darwin" [
    common
    { dotfiles.enable = lib.mkForce false; }
  ];
  devbox = flake.systemConfigs.devbox.config;
  devboxHome = devbox.home-manager.users."zhanghaibin.zhb";
  zhbNixos = flake.nixosConfigurations.zhb-nixos.config;
  zhbHome = zhbNixos.home-manager.users.zhb;
  links = darwin.config.dotfiles;
  roots = builtins.mapAttrs (system: home: {
    config = home.config.dotfiles.configLinks;
    home = home.config.dotfiles.homeLinks;
  }) { inherit darwin linux; };
  checks = {
    zhbNixosIntegrated =
      zhbHome.dotfiles.enable
      && zhbHome.dotfiles.root == "/home/zhb/nix-config/dotfiles"
      && zhbHome.home.homeDirectory == "/home/zhb"
      && zhbHome.home.stateVersion == "26.11"
      && zhbHome.programs.fish.enable
      && zhbNixos.home-manager.useGlobalPkgs
      && zhbNixos.home-manager.useUserPackages
      && zhbNixos.home-manager.backupFileExtension == "before-home-manager";
    zhbCocStateUnmanaged =
      zhbHome.dotfiles.configLinks.coc == null
      && !(zhbHome.xdg.configFile ? coc)
      && zhbHome.dotfiles.configLinks."coc/ultisnips" == ".config/coc/ultisnips"
      && !zhbHome.xdg.configFile."coc/ultisnips".force;
    zhbNoUnrelatedServices = builtins.attrNames zhbHome.systemd.user.services == [ ];
    devboxIntegrated =
      devboxHome.dotfiles.enable
      && devboxHome.dotfiles.root == "/home/zhanghaibin.zhb/nix-config/dotfiles"
      && devboxHome.programs.fish.enable
      && devbox.home-manager.useGlobalPkgs
      && !devbox.users.users."zhanghaibin.zhb".enable;
    directoryNotRecursive = !darwin.config.xdg.configFile.nvim.recursive;
    noForcedOverwrite = !darwin.config.xdg.configFile.nvim.force;
    fishKeepsGeneratedConfig =
      darwin.config.xdg.configFile."fish/config.fish".source != null
      && !(links.configLinks ? "fish/config.fish");
    fishFileLinked = links.configLinks."fish/conf.d/common.fish" == ".config/fish/conf.d/common.fish";
    fishWorktreeFunction =
      links.configLinks."fish/functions/tv-worktree.fish" == ".config/fish/functions/tv-worktree.fish";
    fishTvnFunction =
      lib.all
        (
          home:
          home.dotfiles.configLinks."fish/functions/tvn.fish" == ".config/fish/functions/tvn.fish"
          &&
            lib.hasInfix "${home.dotfiles.root}/.config/fish/functions/tvn.fish"
              home.xdg.configFile."fish/functions/tvn.fish".source.buildCommand
          && !home.xdg.configFile."fish/functions/tvn.fish".force
          && !home.xdg.configFile."fish/functions/tvn.fish".recursive
        )
        [
          darwin.config
          linux.config
          devboxHome
        ];
    darwinOnly =
      !(linux.config.dotfiles.configLinks ? aerospace)
      && links.configLinks.aerospace == ".config/aerospace";
    hammerspoonLocation = links.homeLinks.".hammerspoon" == ".config/hammerspoon";
    noAgentState =
      !(links.homeLinks ? ".pi") && !(links.homeLinks ? ".pi/agent") && !(links.homeLinks ? ".claude");
    piConfigEntries = lib.all (name: links.homeLinks.${name} == name) [
      ".pi/agent/settings.json"
      ".pi/agent/models.json"
      ".pi/agent/hud-footer.json"
      ".pi/agent/extensions"
      ".pi/agent/system-prompts"
      ".pi/agent/shepherdr"
    ];
    piOnlyImmediateChildren =
      let
        names = lib.filter (name: lib.hasPrefix ".pi/" name) (builtins.attrNames links.homeLinks);
      in
      builtins.length names == 6 && lib.all (name: builtins.match "[.]pi/agent/[^/]+" name != null) names;
    piHudFooterLinked =
      lib.all
        (
          home:
          home.dotfiles.homeLinks.".pi/agent/hud-footer.json" == ".pi/agent/hud-footer.json"
          &&
            lib.hasInfix "${home.dotfiles.root}/.pi/agent/hud-footer.json"
              home.home.file.".pi/agent/hud-footer.json".source.buildCommand
          && !home.home.file.".pi/agent/hud-footer.json".force
          && !home.home.file.".pi/agent/hud-footer.json".recursive
        )
        [
          darwin.config
          linux.config
          devboxHome
        ];
    piStampUnmanaged =
      lib.all
        (
          home:
          !(home.dotfiles.homeLinks ? ".pi/agent/pi-stamp.json")
          && !(home.home.file ? ".pi/agent/pi-stamp.json")
          && !(lib.hasInfix "pi-stamp.json" home.home.activation.checkDotfiles.data)
        )
        [
          darwin.config
          linux.config
          devboxHome
        ];
    piEntriesNotForcedOrRecursive = lib.all (
      name:
      let
        file = darwin.config.home.file.${name};
      in
      !file.force && !file.recursive
    ) (lib.filter (name: lib.hasPrefix ".pi/" name) (builtins.attrNames links.homeLinks));
    piLinuxConfig =
      linux.config.dotfiles.homeLinks.".pi/agent/settings.json" == ".pi/agent/settings.json";
    piOutOfStoreSource =
      lib.hasInfix "/tmp/editable-dotfiles/.pi/agent/settings.json"
        darwin.config.home.file.".pi/agent/settings.json".source.buildCommand;
    piDirectoryOutOfStoreSource =
      lib.hasInfix "/tmp/editable-dotfiles/.pi/agent/extensions"
        darwin.config.home.file.".pi/agent/extensions".source.buildCommand;
    piMappingCanBeDisabled = !(overridden.config.home.file ? ".pi/agent/settings.json");
    piDisabledHasNoLinks = !(disabled.config.home.file ? ".pi/agent/settings.json");
    noOpenCode =
      !(lib.any (name: lib.hasPrefix "opencode" name) (builtins.attrNames links.configLinks));
    tuiosDirectory =
      lib.all
        (
          home:
          home.config.dotfiles.configLinks.tuios == ".config/tuios"
          && !home.config.xdg.configFile.tuios.recursive
          && !home.config.xdg.configFile.tuios.force
          && !(lib.any (name: lib.hasPrefix "tuios/" name) (
            builtins.attrNames home.config.dotfiles.configLinks
          ))
          && lib.hasInfix "/tmp/editable-dotfiles/.config/tuios" home.config.xdg.configFile.tuios.source.buildCommand
        )
        [
          darwin
          linux
        ];
    tuiosDisabledHasNoLinks = !(disabled.config.xdg.configFile ? tuios);
    televisionDirectory =
      !darwin.config.xdg.configFile.television.recursive
      && !darwin.config.xdg.configFile.television.force
      && !(lib.any (name: lib.hasPrefix "television/" name) (builtins.attrNames links.configLinks));
    overrideSource = overridden.config.dotfiles.configLinks.nvim == ".config/custom-nvim";
    excludeMapping = !(overridden.config.xdg.configFile ? kitty);
    disabledHasNoLinks = !(disabled.config.xdg.configFile ? nvim);
    missingSourceCheck = builtins.elem "checkLinkTargets" darwin.config.home.activation.checkDotfiles.before;
    outOfStoreSource = darwin.config.xdg.configFile.nvim.source != null;
    aliasUsesCheckout = lib.hasInfix "git -C /tmp/editable-dotfiles" darwin.config.programs.fish.interactiveShellInit;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed dotfiles checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks roots;
  # Forcing the activation derivation checks Home Manager assertions as well.
  activationDrv = darwin.activationPackage.drvPath;
  symlink = {
    drvPath = darwin.config.xdg.configFile.nvim.source.drvPath;
    target = darwin.config.xdg.configFile.nvim.source.target or null;
  };
}
