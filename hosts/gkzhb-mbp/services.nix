{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.bytedance.home;
  credentialPath = config.sops.secrets.ttyd-credential.path;
  certPath = "${home}/.config/ttyd/fullchain.pem";
  keyPath = "${home}/.config/ttyd/privkey.pem";
  startTtyd = pkgs.writeShellScript "start-ttyd" ''
    for file in ${lib.escapeShellArg certPath} ${lib.escapeShellArg keyPath}; do
      if [[ ! -s "$file" || ! -r "$file" ]]; then
        echo "Missing or unreadable ttyd TLS file: $file" >&2
        exit 1
      fi
    done
    credential="$(< ${lib.escapeShellArg credentialPath})" || exit 1
    if [[ "$credential" != *:* || -z "''${credential%%:*}" || -z "''${credential#*:}" || "$credential" == *$'\n'* || "$credential" == *$'\r'* ]]; then
      echo "Invalid ttyd credential: expected a single username:password line" >&2
      exit 1
    fi
    exec ${pkgs.ttyd}/bin/ttyd \
      --interface 0.0.0.0 --port 7681 \
      --ssl --ssl-cert ${lib.escapeShellArg certPath} --ssl-key ${lib.escapeShellArg keyPath} \
      --credential "$credential" --writable \
      ${pkgs.fish}/bin/fish --login
  '';
in
{
  system.primaryUser = "bytedance";

  sops.secrets.ttyd-credential = {
    sopsFile = ../../secrets/godns-mbp.yaml;
    key = "ttyd-credential";
    owner = "bytedance";
    mode = "0400";
  };

  launchd.user.agents = {
    # Listen on all IPv4 interfaces; HTTPS and Basic Auth remain required.
    # Origin checking is disabled, so use only on trusted networks.
    ttyd = {
      serviceConfig = {
        ProgramArguments = [ "${startTtyd}" ];
        WorkingDirectory = home;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${home}/Library/Logs/ttyd.log";
        StandardErrorPath = "${home}/Library/Logs/ttyd.error.log";
      };
    };
    dsh = {
      command = "${pkgs.fish}/bin/fish -l /Users/bytedance/scripts/mcps/dsh.fish";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
      };
    };
  };
  launchd.daemons.nix-daemon.serviceConfig.EnvironmentVariables = {
    HTTP_PROXY = "http://localhost:10881";
    HTTPS_PROXY = "http://localhost:10881";
    NO_PROXY = "localhost,127.0.0.1";
  };
}
