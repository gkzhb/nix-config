# Evaluate the actual devbox timer and service without renewal or activation.
# just test-certbot
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config;
  service = cfg.systemd.services.certbot-renew;
  timer = cfg.systemd.timers.certbot-renew;
  checks = {
    rootOneshot = service.serviceConfig.Type == "oneshot" && service.serviceConfig.User == "root";
    timerOnly = service.wantedBy == [ ];
    networkReady =
      builtins.elem "network-online.target" service.wants
      && builtins.elem "network-online.target" service.after;
    existingCertbot = lib.hasPrefix "/home/zhanghaibin.zhb/.local/bin/certbot renew " service.serviceConfig.ExecStart;
    existingLineage = lib.hasInfix "--cert-name byte.gkzhb.top" service.serviceConfig.ExecStart;
    unattended =
      lib.hasInfix "--non-interactive" service.serviceConfig.ExecStart
      && lib.hasInfix "--no-random-sleep-on-renew" service.serviceConfig.ExecStart
      && service.serviceConfig.Environment == "HOME=/root";
    deployHookOnly =
      lib.hasInfix "--deploy-hook" service.serviceConfig.ExecStart
      && lib.hasInfix "certbot-deploy.sh" service.serviceConfig.ExecStart
      && !(service.serviceConfig ? ExecStartPost);
    privateFiles = service.serviceConfig.UMask == "0077";
    monthlyPersistentTimer =
      timer.timerConfig.OnCalendar == "*-*-01 03:00:00"
      && timer.timerConfig.Persistent
      && timer.timerConfig.Unit == "certbot-renew.service"
      && builtins.elem "timers.target" timer.wantedBy;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed certbot checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  units = {
    service = cfg.systemd.units."certbot-renew.service".text;
    timer = cfg.systemd.units."certbot-renew.timer".text;
  };
}
