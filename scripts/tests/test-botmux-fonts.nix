# Evaluate the real host wiring without activation or plaintext secrets.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-botmux-fonts.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config.home-manager.users."zhanghaibin.zhb";
  names = [
    "JetBrainsMono-Regular.ttf"
    "JetBrainsMono-Bold.ttf"
    "NotoSansMonoCJKsc-Regular.otf"
    "NotoSansMonoCJKsc-Bold.otf"
    "NotoColorEmoji.ttf"
  ];
  targets = map (name: ".botmux/fonts/${name}") names;
  botmuxFiles = home: lib.filterAttrs (name: _: lib.hasPrefix ".botmux/fonts" name) home.home.file;
  # Check other module sources rather than their unrelated package closures.
  # A removed package on mido must not block this devbox font regression.
  nixFiles =
    directory:
    lib.concatMap (
      name:
      let
        path = directory + "/${name}";
        type = (builtins.readDir directory).${name};
      in
      if type == "directory" then
        nixFiles path
      else
        lib.optional (type == "regular" && lib.hasSuffix ".nix" name) path
    ) (builtins.attrNames (builtins.readDir directory));
  scopedSources = nixFiles ../../hosts ++ nixFiles ../../modules ++ nixFiles ../../flake;
  otherSources = builtins.filter (
    path: path != ../../hosts/devbox/user.nix && path != ../../hosts/devbox/botmux-fonts.nix
  ) scopedSources;
  checks = {
    exactFiveLinks = builtins.attrNames (botmuxFiles cfg) == lib.sort builtins.lessThan targets;
    nixSources = builtins.all (
      target: lib.hasPrefix builtins.storeDir (toString cfg.home.file.${target}.source)
    ) targets;
    individualSafeLinks = builtins.all (
      target: !cfg.home.file.${target}.force && !cfg.home.file.${target}.recursive
    ) targets;
    expectedSourceNames = builtins.all (
      target: baseNameOf cfg.home.file.${target}.source == baseNameOf target
    ) targets;
    noOtherHostLinks = builtins.all (
      path:
      let
        content = builtins.readFile path;
      in
      !(lib.hasInfix "botmux-fonts.nix" content) && !(lib.hasInfix ".botmux/fonts" content)
    ) otherSources;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
  source = cfg.home.file.".botmux/fonts/JetBrainsMono-Regular.ttf".source;
in
assert lib.assertMsg (
  failures == [ ]
) "Failed Botmux font checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  fontBundle = dirOf source;
  fontBundleDrv = builtins.head (builtins.attrNames (builtins.getContext source));
  homeFiles = cfg.home-files.outPath;
  homeFilesDrv = cfg.home-files.drvPath;
}
