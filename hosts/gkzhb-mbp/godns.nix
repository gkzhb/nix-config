{
  config,
  pkgs,
  ...
}:
let
  # Upstream 3.3.6 skips private interface addresses, even with ip_interface.
  # Allow private IPv4 for LAN DDNS, but still reject non-unicast addresses
  # and private IPv6. Fail the build if the upstream code changes.
  godns = pkgs.godns.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace pkg/lib/ip_helper.go \
        --replace-fail 'if ip.IsPrivate() {' \
        'if !ip.IsGlobalUnicast() || (ip.IsPrivate() && ip.To4() == nil) {'
    '';
  });
  home = config.users.users.bytedance.home;
  configPath = config.sops.secrets.godns-mbp.path;
in
{
  environment.systemPackages = [ godns ];

  # Only encrypted data enters the Nix store; sops-nix decrypts at runtime.
  sops = {
    age.keyFile = "${home}/.config/sops/age/keys.txt";
    age.sshKeyPaths = [ ];
    gnupg.sshKeyPaths = [ ];
    secrets.godns-mbp = {
      sopsFile = ../../secrets/godns-mbp.yaml;
      key = "godns-config";
      path = "/run/secrets/godns-mbp.json";
      owner = "bytedance";
      mode = "0400";
    };
  };

  launchd.user.agents.godns = {
    serviceConfig = {
      ProgramArguments = [
        "${godns}/bin/godns"
        "-c"
        configPath
        "-a"
        "127.0.0.1:9000"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 60;
      StandardOutPath = "${home}/Library/Logs/godns.log";
      StandardErrorPath = "${home}/Library/Logs/godns.error.log";
    };
  };
}
