{
  config,
  pkgs,
  ...
}:

{
  systemd.services.frp = {
    description = "frp server service";
    wantedBy = [ "system-manager.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.frp}/bin/frps -c /etc/frp/frps.toml";
      Restart = "always";
    };
  };

  systemd.services.xray = {
    description = "xray proxy service";
    wantedBy = [ "system-manager.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xray}/bin/xray -config /etc/xray/config.json";
      Restart = "always";
    };
  };

  systemd.services.tailscaled = {
    description = "Tailscale node agent";
    wantedBy = [ "system-manager.target" ];
    after = [
      "network-pre.target"
      "NetworkManager.service"
      "systemd-resolved.service"
    ];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.tailscale}/bin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/run/tailscale/tailscaled.sock $FLAGS";
      ExecStopPost = "${pkgs.tailscale}/bin/tailscaled --cleanup";
      Restart = "on-failure";
      RuntimeDirectory = "tailscale";
      RuntimeDirectoryMode = "0755";
      StateDirectory = "tailscale";
      StateDirectoryMode = "0700";
      CacheDirectory = "tailscale";
      CacheDirectoryMode = "0750";
    };
  };
}
