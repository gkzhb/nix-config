{ config, pkgs, ... }:
let
  # Immutable store script: root never executes a user-writable checkout file.
  cleanup = pkgs.writeShellScript "nix-darwin-system-gc" (
    builtins.readFile ../../scripts/nix-darwin-gc.sh
  );
in
{
  # Use one count-based system-profile job, not age-based pruning of all profiles.
  nix.gc.automatic = false;

  launchd.daemons.nix-system-gc = {
    serviceConfig = {
      ProgramArguments = [
        "${cleanup}"
        "${config.nix.package}/bin"
        "/nix/var/nix/profiles/system"
      ];
      UserName = "root";
      StartCalendarInterval = {
        Weekday = 0;
        Hour = 3;
        Minute = 0;
      };
      RunAtLoad = false;
      KeepAlive = false;
      ProcessType = "Background";
      LowPriorityIO = true;
      StandardOutPath = "/var/log/nix-system-gc.log";
      StandardErrorPath = "/var/log/nix-system-gc.error.log";
    };
  };
}
