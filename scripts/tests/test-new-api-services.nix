# Evaluate actual devbox System Manager/HM wiring without activation.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-new-api-services.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config;
  hm = cfg.home-manager.users."zhanghaibin.zhb";
  api = hm.systemd.user.services.newapi;
  apiCommand = lib.head api.Service.ExecStart;
  redis = cfg.systemd.services.redis;
  redisConfig = builtins.elemAt (lib.splitString " " redis.serviceConfig.ExecStart) 1;
  checks = {
    latestPackage = lib.hasInfix "new-api-${flake.packages.x86_64-linux.new-api.version}" apiCommand;
    existingListener =
      builtins.length api.Service.ExecStart == 1
      && lib.hasSuffix "/bin/new-api --port 3000 --log-dir ./logs" apiCommand;
    existingDatabase =
      api.Service.WorkingDirectory == "%h/scripts/services/newapi"
      && builtins.elem "SQLITE_PATH=one-api.db?_pragma=busy_timeout(30000)&_pragma=journal_mode(WAL)&_txlock=immediate" api.Service.Environment;
    sharedSystemRedis =
      redis.wantedBy == [ "system-manager.target" ]
      && !(hm.systemd.user.services ? newapi-redis)
      && builtins.elem "REDIS_CONN_STRING=redis://127.0.0.1:6379/0" api.Service.Environment;
    noCrossManagerDependencies =
      (api.Unit.Wants or [ ]) == [ ]
      && (api.Unit.After or [ ]) == [ ]
      && (api.Unit.Requires or [ ]) == [ ];
    readiness = redis.serviceConfig.Type == "notify" && redis.serviceConfig.NotifyAccess == "main";
    portableLocale = redis.environment.LANG == "C.UTF-8" && redis.environment.LC_ALL == "C.UTF-8";
    privatePersistentState =
      redis.serviceConfig.StateDirectory == "redis"
      && redis.serviceConfig.StateDirectoryMode == "0700"
      && redis.serviceConfig.WorkingDirectory == "/var/lib/redis"
      && redis.serviceConfig.DynamicUser;
    cliAvailable = builtins.elem cfg.nixpkgs.pkgs.redis cfg.environment.systemPackages;
    startsAndRecovers =
      api.Install.WantedBy == [ "default.target" ]
      && api.Service.Restart == "on-failure"
      && redis.serviceConfig.Restart == "on-failure";
    restrictiveUmask = api.Service.UMask == "0077" && redis.serviceConfig.UMask == "0077";
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed New API service checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks redisConfig;
  apiUnit = hm.xdg.configFile."systemd/user/newapi.service".source;
  redisUnit = cfg.systemd.units."redis.service".unit;
}
