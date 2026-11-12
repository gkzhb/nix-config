# Evaluate actual devbox System Manager Dolt/SOPS wiring without activation.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-dolt-service.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config;
  pkgs = cfg.nixpkgs.pkgs;
  hm = cfg.home-manager.users."zhanghaibin.zhb";
  dolt = cfg.systemd.services.dolt;
  service = dolt.serviceConfig;
  serverConfig = builtins.elemAt (lib.splitString " " service.ExecStart) 3;
  checks = {
    systemServiceOnly = !(hm.systemd.user.services ? dolt);
    normalUser = service.User == "zhanghaibin.zhb" && service.Group == "zhanghaibin.zhb";
    packagedCommand =
      lib.hasPrefix "${pkgs.dolt}/bin/dolt sql-server --config " service.ExecStart
      && lib.hasSuffix " --skip-root-user-initialization" service.ExecStart;
    persistentData = service.WorkingDirectory == "/home/zhanghaibin.zhb/scripts/services/dolt";
    privateDirectory = builtins.elem "d /home/zhanghaibin.zhb/scripts/services/dolt 0700 zhanghaibin.zhb zhanghaibin.zhb -" cfg.systemd.tmpfiles.rules;
    directoryReady =
      builtins.elem "dolt-data-directory.service" dolt.after
      && builtins.elem "dolt-data-directory.service" dolt.requires
      && cfg.systemd.services.dolt-data-directory.serviceConfig.User == service.User;
    privateSocket = service.RuntimeDirectory == "dolt" && service.RuntimeDirectoryMode == "0700";
    waitsForSecrets =
      builtins.elem "sops-install-secrets.service" dolt.after
      && builtins.elem "sops-install-secrets.service" dolt.requires;
    oldUserUnitRemovedFirst =
      builtins.elem "home-manager-zhanghaibin.zhb.service" dolt.after
      && builtins.elem "home-manager-zhanghaibin.zhb.service" dolt.requires;
    originalCertificates =
      service.LoadCredential == [
        "root-password:${cfg.sops.secrets.dolt-root-password.path}"
        "tls-cert:/etc/letsencrypt/live/byte.gkzhb.top/fullchain.pem"
        "tls-key:/etc/letsencrypt/live/byte.gkzhb.top/privkey.pem"
      ]
      && lib.hasInfix "dolt-prepare-root.py" service.ExecStartPre;
    passwordOnlySops =
      builtins.attrNames cfg.sops.secrets == [ "dolt-root-password" ]
      && cfg.sops.secrets.dolt-root-password.mode == "0400"
      && cfg.sops.secrets.dolt-root-password.owner == "root"
      && cfg.sops.age.keyFile == "/home/zhanghaibin.zhb/.config/sops/age/keys.txt"
      && cfg.sops.age.generateKey == false
      && cfg.sops.useSystemdActivation
      && cfg.sops.secrets.dolt-root-password.restartUnits == [ "dolt.service" ];
    startsAndRecovers =
      dolt.wantedBy == [ "system-manager.target" ]
      && service.Restart == "on-failure"
      && service.RestartSec == "5s";
    privateFiles = service.UMask == "0077" && service.NoNewPrivileges && service.RestrictSUIDSGID;
    cliAvailable = builtins.elem pkgs.dolt cfg.environment.systemPackages;
    cryptoToolsAvailable = lib.all (p: builtins.elem p cfg.environment.systemPackages) [
      pkgs.sops
      pkgs.age
      pkgs.mkcert
      pkgs.openssl
    ];
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed Dolt service checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks serverConfig;
  unit = cfg.systemd.units."dolt.service".unit;
}
