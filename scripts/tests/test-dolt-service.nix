# Evaluate the actual devbox Home Manager wiring without activation.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-dolt-service.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config;
  pkgs = cfg.nixpkgs.pkgs;
  hm = cfg.home-manager.users."zhanghaibin.zhb";
  dolt = hm.systemd.user.services.dolt;
  checks = {
    userServiceOnly = !(cfg.systemd.services ? dolt);
    packagedCommand =
      dolt.Service.ExecStart == [
        "${cfg.nixpkgs.pkgs.dolt}/bin/dolt sql-server --host 0.0.0.0 --port 3307 --data-dir . --doltcfg-dir .doltcfg --socket %t/dolt.sock --skip-root-user-initialization"
      ];
    persistentData = dolt.Service.WorkingDirectory == "%h/scripts/services/dolt";
    privateDirectory = builtins.elem "d %h/scripts/services/dolt 0700 - - -" hm.systemd.user.tmpfiles.rules;
    directoryReady =
      builtins.elem "systemd-tmpfiles-setup.service" dolt.Unit.After
      && builtins.elem "systemd-tmpfiles-setup.service" dolt.Unit.Requires;
    waitsForSecrets =
      builtins.elem "sops-nix.service" dolt.Unit.After
      && builtins.elem "sops-nix.service" dolt.Unit.Requires;
    credentialNotInCommand =
      dolt.Service.LoadCredential == [ "root-password:${hm.sops.secrets.dolt-root-password.path}" ]
      && pkgs.lib.hasInfix "dolt-prepare-root.py" dolt.Service.ExecStartPre;
    encryptedPassword =
      hm.sops.secrets.dolt-root-password.mode == "0400"
      && hm.sops.age.keyFile == "${hm.home.homeDirectory}/.config/sops/age/keys.txt"
      && hm.sops.age.generateKey == false
      && builtins.baseNameOf hm.sops.defaultSopsFile == "devbox-dolt.yaml";
    startsAndRecovers =
      dolt.Install.WantedBy == [ "default.target" ]
      && dolt.Service.Restart == "on-failure"
      && dolt.Service.RestartSec == "5s";
    privateFiles =
      dolt.Service.UMask == "0077" && dolt.Service.NoNewPrivileges && dolt.Service.RestrictSUIDSGID;
    cliAvailable = builtins.elem cfg.nixpkgs.pkgs.dolt hm.home.packages;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed Dolt service checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  unit = hm.xdg.configFile."systemd/user/dolt.service".source;
}
