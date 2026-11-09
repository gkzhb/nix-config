{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.system-manager-gc;
in
{
  options.services.system-manager-gc = {
    enable = lib.mkEnableOption "scheduled System Manager generation cleanup and Nix garbage collection";

    keepGenerations = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = ''
        Number of System Manager generations to keep, including the current
        generation. Nix also preserves generations newer than the current one
        if the profile has been rolled back.
      '';
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      example = "Sun *-*-* 03:00:00";
      description = "systemd calendar expression for generation cleanup and garbage collection.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "1h";
      description = "Maximum randomized delay before running the scheduled cleanup.";
    };

    profile = lib.mkOption {
      type = lib.types.str;
      default = "/nix/var/nix/profiles/system-manager-profiles/system-manager";
      description = "Absolute path to the System Manager generation profile (not a store path).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.profile;
        message = "services.system-manager-gc.profile must be an absolute path.";
      }
    ];

    systemd.services.system-manager-gc = {
      description = "Prune System Manager generations and collect unused Nix store paths";
      unitConfig.ConditionPathExists = cfg.profile;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        # Run GC only after pruning succeeds. Do not use collect-garbage -d:
        # other system/user profiles must retain their generation history.
        ExecStartPre = "${config.nix.package}/bin/nix-env --profile ${utils.escapeSystemdExecArg cfg.profile} --delete-generations +${toString cfg.keepGenerations}";
        ExecStart = "${config.nix.package}/bin/nix-store --gc";
      };
    };

    systemd.timers.system-manager-gc = {
      description = "Scheduled System Manager generation cleanup and Nix garbage collection";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "system-manager-gc.service";
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };
    };
  };
}
