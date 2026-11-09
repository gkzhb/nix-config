# Evaluation only: no activation, generation deletion or garbage collection.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-system-manager-gc.nix
let
  flake = builtins.getFlake (toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  mkSystem =
    extra:
    (flake.inputs.system-manager.lib.makeSystemConfig {
      modules = [
        ../../modules/system-manager/garbage-collection.nix
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system-manager.allowAnyDistro = true;
        }
        extra
      ];
    }).config;
  defaults = mkSystem { services.system-manager-gc.enable = true; };
  disabled = mkSystem { };
  overridden = mkSystem {
    services.system-manager-gc = {
      enable = true;
      keepGenerations = 7;
      onCalendar = "Sun *-*-* 03:00:00";
      randomizedDelaySec = "10m";
      profile = "/nix/var/nix/profiles/custom-system-manager";
    };
  };
  invalid = mkSystem {
    services.system-manager-gc = {
      enable = true;
      keepGenerations = 0;
    };
  };
  relative = mkSystem {
    services.system-manager-gc = {
      enable = true;
      profile = "relative-profile";
    };
  };
  service = defaults.systemd.services.system-manager-gc;
  timer = defaults.systemd.timers.system-manager-gc;
  customService = overridden.systemd.services.system-manager-gc;
  customTimer = overridden.systemd.timers.system-manager-gc;
  checks = {
    disabledByDefault =
      !(disabled.systemd.services ? system-manager-gc) && !(disabled.systemd.timers ? system-manager-gc);
    keepFive = defaults.services.system-manager-gc.keepGenerations == 5;
    rootOneshot = service.serviceConfig.User == "root" && service.serviceConfig.Type == "oneshot";
    explicitProfile =
      service.serviceConfig.ExecStartPre
      == "${defaults.nix.package}/bin/nix-env --profile \"/nix/var/nix/profiles/system-manager-profiles/system-manager\" --delete-generations +5";
    gcAfterPrune = service.serviceConfig.ExecStart == "${defaults.nix.package}/bin/nix-store --gc";
    onlyTimerStartsService = service.wantedBy == [ ];
    missingProfileSkipped =
      service.unitConfig.ConditionPathExists == defaults.services.system-manager-gc.profile;
    weeklyPersistentTimer =
      timer.timerConfig.OnCalendar == "weekly"
      && timer.timerConfig.Persistent
      && timer.timerConfig.RandomizedDelaySec == "1h"
      && timer.timerConfig.Unit == "system-manager-gc.service"
      && builtins.elem "timers.target" timer.wantedBy;
    customRetention = lib.hasSuffix "--delete-generations +7" customService.serviceConfig.ExecStartPre;
    customProfile =
      customService.unitConfig.ConditionPathExists == overridden.services.system-manager-gc.profile
      && lib.hasInfix "--profile \"/nix/var/nix/profiles/custom-system-manager\"" customService.serviceConfig.ExecStartPre;
    customSchedule =
      customTimer.timerConfig.OnCalendar == "Sun *-*-* 03:00:00"
      && customTimer.timerConfig.RandomizedDelaySec == "10m";
    rejectZeroRetention =
      !(builtins.tryEval invalid.services.system-manager-gc.keepGenerations).success;
    # makeSystemConfig checks assertions before returning its config passthru.
    rejectRelativeProfile = !(builtins.tryEval relative).success;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed System Manager GC checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  # Force unit rendering as well as the high-level service/timer options.
  units = {
    service = defaults.systemd.units."system-manager-gc.service".text;
    timer = defaults.systemd.units."system-manager-gc.timer".text;
  };
}
