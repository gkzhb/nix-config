# Evaluate the actual devbox package and service, without activation or secrets.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-magpie-service.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config.home-manager.users."zhanghaibin.zhb";
  package = flake.inputs.magpie-releases.packages.x86_64-linux.magpie-cli;
  unit = cfg.systemd.user.services.magpie;
  environment = unit.Service.Environment;
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  checks = {
    officialInput =
      lock.nodes.magpie-releases.locked.owner == "yetone"
      && lock.nodes.magpie-releases.locked.repo == "magpie-releases";
    followsHostNixpkgs = lock.nodes.magpie-releases.inputs.nixpkgs == [ "nixpkgs" ];
    terminalPackageInstalled = builtins.any (p: p.outPath == package.outPath) cfg.home.packages;
    sameExportedPackage = flake.packages.x86_64-linux.magpie-cli.outPath == package.outPath;
    foregroundServer =
      unit.Service.Type == "simple" && unit.Service.ExecStart == [ "${package}/bin/magpie serve" ];
    autoStart = unit.Install.WantedBy == [ "default.target" ];
    loopbackOnly = builtins.elem "MAGPIE_ADDR=127.0.0.1:3425" environment;
    noImplicitAccountDiscovery = builtins.elem "MAGPIE_NO_ACCOUNTS=1" environment;
    noTelemetry = builtins.elem "DO_NOT_TRACK=1" environment;
    privateWrites =
      unit.Service.UMask == "0077" && unit.Service.NoNewPrivileges && unit.Service.RestrictSUIDSGID;
    gracefulStop = builtins.elem "MAGPIE_DRAIN=30s" environment && unit.Service.TimeoutStopSec == "45s";
    restartOnFailure = unit.Service.Restart == "on-failure" && unit.Service.RestartSec == "5s";
    preserveUserConfig =
      unit.Service.WorkingDirectory == "%h"
      && builtins.elem "XDG_CONFIG_HOME=%h/.config" environment
      && !(builtins.hasAttr ".config/magpie/settings.json" cfg.home.file);
    existingNewApiIntact = builtins.any (lib.hasInfix "--port 3000") cfg.systemd.user.services.newapi.Service.ExecStart;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed Magpie checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  version = package.version;
  packageDrv = package.drvPath;
  inherit unit;
}
