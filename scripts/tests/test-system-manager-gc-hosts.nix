# Optional host integration evaluation; may fetch large transitive flake inputs.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-system-manager-gc-hosts.nix
let
  flake = builtins.getFlake (toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  hosts = [
    "devbox"
    "gkzhb-vps"
    "mido"
  ];
  checks = lib.genAttrs hosts (
    name:
    let
      cfg = flake.systemConfigs.${name}.config;
    in
    cfg.services.system-manager-gc.enable
    && cfg.services.system-manager-gc.keepGenerations == 5
    && cfg.systemd.timers.system-manager-gc.timerConfig.OnCalendar == "weekly"
  );
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed GC host integration: ${lib.concatStringsSep ", " failures}";
checks
