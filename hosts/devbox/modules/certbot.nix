{ pkgs, utils, ... }:

let
  # Keep the existing uv installation and DNS plugin. The pinned nixpkgs
  # certbot-dns-cloudflare is marked broken; do not bypass that check here.
  certbot = "/home/zhanghaibin.zhb/.local/bin/certbot";
  deployHook = "${pkgs.bash}/bin/bash ${../../../scripts/certbot-deploy.sh} ${pkgs.systemd}/bin/systemctl";
in
{
  systemd.services.certbot-renew = {
    description = "Renew devbox Let's Encrypt certificate";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Environment = "HOME=/root";
      UMask = "0077";
      # Reuse /etc/letsencrypt/renewal/byte.gkzhb.top.conf, including its
      # runtime Cloudflare credential path. Never import credentials into Nix.
      ExecStart = "${certbot} renew --cert-name byte.gkzhb.top --non-interactive --no-random-sleep-on-renew --deploy-hook ${utils.escapeSystemdExecArg deployHook}";
    };
  };

  systemd.timers.certbot-renew = {
    description = "Renew devbox certificate monthly at 03:00 on day 1";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-01 03:00:00";
      Persistent = true;
      Unit = "certbot-renew.service";
    };
  };
}
