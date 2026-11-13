# Evaluation/build only: no daemon loading, pruning, or garbage collection.
let
  flake = builtins.getFlake (toString ../..);
  system = flake.inputs.nix-darwin.lib.darwinSystem {
    modules = [
      ../../hosts/gkzhb-mbp/garbage-collection.nix
      {
        nixpkgs.hostPlatform = "aarch64-darwin";
        nix.enable = true;
        system.stateVersion = 6;
      }
    ];
  };
  inherit (system) config;
  job = config.launchd.daemons.nix-system-gc.serviceConfig;
  text = config.environment.launchDaemons."org.nixos.nix-system-gc.plist".text;
  checks = {
    separateBuiltinGcDisabled = !config.nix.gc.automatic;
    root = job.UserName == "root";
    weeklySundayThree =
      job.StartCalendarInterval.Weekday == 0
      && job.StartCalendarInterval.Hour == 3
      && job.StartCalendarInterval.Minute == 0;
    noRunOnInstall = !job.RunAtLoad && !job.KeepAlive;
    immutableScript = flake.inputs.nixpkgs.lib.hasPrefix "/nix/store/" (
      builtins.head job.ProgramArguments
    );
    explicitSystemProfile = builtins.elemAt job.ProgramArguments 2 == "/nix/var/nix/profiles/system";
    nixBin = builtins.elemAt job.ProgramArguments 1 == "${config.nix.package}/bin";
    logs =
      job.StandardOutPath == "/var/log/nix-system-gc.log"
      && job.StandardErrorPath == "/var/log/nix-system-gc.error.log";
    rendered = builtins.match ".*StartCalendarInterval.*" text != null;
  };
  failures = builtins.attrNames (flake.inputs.nixpkgs.lib.filterAttrs (_: passed: !passed) checks);
in
assert failures == [ ];
{
  inherit checks;
  plist = config.environment.launchDaemons."org.nixos.nix-system-gc.plist".source;
  script = builtins.head job.ProgramArguments;
  serviceConfig = job;
}
