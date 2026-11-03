{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.users.users.bytedance.home;
  certPath = "${home}/.config/ttyd/fullchain.pem";
  keyPath = "${home}/.config/ttyd/privkey.pem";
  passwordPath = "${home}/.config/tuios/web-password";
  startTuiosWeb = pkgs.writeShellScript "start-tuios-web" ''
    for file in ${lib.escapeShellArg certPath} ${lib.escapeShellArg keyPath} ${lib.escapeShellArg passwordPath}; do
      if [[ ! -s "$file" || ! -r "$file" ]]; then
        echo "Missing or unreadable tuios-web TLS/password file: $file" >&2
        exit 1
      fi
    done
    exec ${pkgs.edge.tuios}/bin/tuios-web \
      --host 0.0.0.0 --port 7682 \
      --cert ${lib.escapeShellArg certPath} --key ${lib.escapeShellArg keyPath} \
      --password-file ${lib.escapeShellArg passwordPath}
  '';
in
{
  system.primaryUser = "bytedance";

  launchd.user.agents = {
    # Listen on all IPv4 interfaces; require TLS and the existing runtime password file.
    tuios-web = {
      serviceConfig = {
        ProgramArguments = [ "${startTuiosWeb}" ];
        # launchd does not inherit the login shell's environment.
        EnvironmentVariables = {
          # tuios-web starts tuios by name.
          PATH = "${
            lib.makeBinPath [ pkgs.edge.tuios ]
          }:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          XDG_CONFIG_HOME = "${home}/.config";
        };
        WorkingDirectory = home;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${home}/Library/Logs/tuios-web.log";
        StandardErrorPath = "${home}/Library/Logs/tuios-web.error.log";
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
