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
    }
  ];
  disabled = mkHome "aarch64-darwin" [
    common
    { dotfiles.enable = lib.mkForce false; }
  ];
  links = darwin.config.dotfiles;
  roots = builtins.mapAttrs (system: home: {
    config = home.config.dotfiles.configLinks;
    home = home.config.dotfiles.homeLinks;
  }) { inherit darwin linux; };
  checks = {
    directoryNotRecursive = !darwin.config.xdg.configFile.nvim.recursive;
    noForcedOverwrite = !darwin.config.xdg.configFile.nvim.force;
    fishKeepsGeneratedConfig =
      darwin.config.xdg.configFile."fish/config.fish".source != null
      && !(links.configLinks ? "fish/config.fish");
    fishFileLinked = links.configLinks."fish/conf.d/common.fish" == ".config/fish/conf.d/common.fish";
    darwinOnly =
      !(linux.config.dotfiles.configLinks ? aerospace)
      && links.configLinks.aerospace == ".config/aerospace";
    hammerspoonLocation = links.homeLinks.".hammerspoon" == ".config/hammerspoon";
    noAgentState = !(links.homeLinks ? ".pi") && !(links.homeLinks ? ".claude");
    noOpenCode =
      !(lib.any (name: lib.hasPrefix "opencode" name) (builtins.attrNames links.configLinks));
    tuiosWindowManager =
      links.configLinks."tuios/window-manager.py" == ".config/tuios/window-manager.py"
      && !(links.configLinks ? "tuios/television")
      && links.configLinks.television == ".config/television";
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
