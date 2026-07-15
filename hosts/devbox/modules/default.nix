{ pkgs, ... }:

let
  vncUser = "zhanghaibin.zhb";
  vncHome = "/home/${vncUser}";
  vncRuntimeDir = "tigervnc-zhanghaibin-zhb";
  vncConfigDir = "${vncHome}/.config/tigervnc";
in

{
  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = "x86_64-linux";

    nix = {
      package = pkgs.nix;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "root"
          "zhanghaibin.zhb"
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      git
      python3
      fish
      tmux
      zenith
      just
      tree-sitter
      fzf
      fd
      neovim
      python313Packages.pynvim
      yazi
      zoxide
      ripgrep
      uv
      ty
      ruff
      bun
      code-server
      xray
      taskwarrior3
      nil
      nixfmt
      v2raya
      thrift-ls
      chromium
      llm-agents.claude-code
      llm-agents.agent-browser
      timewarrior
      taskwarrior-tui

      # GUI apps
      tigervnc
      xfce4-session
      xfconf
      xfce4-panel
      xfce4-terminal
      xfdesktop
      xfwm4
      xfce4-settings
      thunar
      hicolor-icon-theme
      dbus
      xauth
      firefox
      brave
    ];

    security.sudo = {
      enable = true;
      extraRules = [
        {
          groups = [ "sudo" ];
          commands = [ "ALL" ];
        }
        {
          users = [ "zhanghaibin.zhb" ];
          commands = [
            {
              command = "/usr/bin/systemctl";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

    systemd.services = {
      nix-daemon = {
        description = "Nix Daemon, with Determinate Nix superpowers.";
        documentation = [
          "man:nix-daemon"
          "https://determinate.systems"
        ];
        wantedBy = [ "multi-user.target" ];
        unitConfig = {
          RequiresMountsFor = [
            "/nix/store"
            "/nix/var"
            "/nix/var/nix/db"
          ];
          ConditionPathIsReadWrite = "/nix/var/nix/daemon-socket";
        };
        serviceConfig = {
          ExecStart = "@/usr/local/bin/determinate-nixd determinate-nixd daemon";
          KillMode = "process";
          LimitNOFILE = 1048576;
          LimitSTACK = "64M";
          TasksMax = 1048576;
          Environment = [
            "http_proxy=http://localhost:10881"
            "https_proxy=http://localhost:10881"
            "no_proxy=localhost,127.0.0.1"
          ];
        };
      };
      tigervnc = {
        description = "TigerVNC server";
        wantedBy = [ "system-manager.target" ];
        after = [ "network.target" ];
        path = with pkgs; [
          coreutils
          dbus
          hicolor-icon-theme
          procps
          thunar
          xauth
          xfce4-panel
          xfce4-session
          xfce4-settings
          xfce4-terminal
          xfconf
          xfdesktop
          xfwm4
          xrdb
          tailscale
          gnugrep
          gnused
        ];
        serviceConfig = {
          Type = "simple";
          User = vncUser;
          Group = vncUser;
          WorkingDirectory = vncHome;
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          KillMode = "mixed";
          TimeoutStopSec = "30s";
          ExecStartPre = [
            "${pkgs.coreutils}/bin/install -d -m 700 ${vncConfigDir}"
            "+${pkgs.coreutils}/bin/install -d -m 755 /usr/share/xsessions"
            "+${pkgs.coreutils}/bin/ln -sf ${pkgs.xfce4-session}/share/xsessions/xfce.desktop /usr/share/xsessions/xfce.desktop"
            (pkgs.writeShellScript "prepare-tigervnc-config" ''
                          set -eu

                          legacy_passwd="${vncHome}/.vnc/passwd"
                          config_passwd="${vncConfigDir}/passwd"

                          if [ -f "$config_passwd" ]; then
                            :
                          elif [ -f "$legacy_passwd" ]; then
                            ${pkgs.coreutils}/bin/cp "$legacy_passwd" "$config_passwd"
                            ${pkgs.coreutils}/bin/chmod 600 "$config_passwd"
                          else
                            echo "missing VNC password file: $config_passwd" >&2
                            echo "create it with: sudo -u ${vncUser} ${pkgs.tigervnc}/bin/vncpasswd ${vncConfigDir}/passwd" >&2
                            exit 1
                          fi

                          cat > "${vncConfigDir}/config" <<EOF
              session=xfce
              geometry=1920x1080
              depth=24
              securitytypes=vncauth
              localhost=no
              alwaysshared
              rfbauth=${vncConfigDir}/passwd
              EOF
                          ${pkgs.coreutils}/bin/chmod 600 "${vncConfigDir}/config"
            '')
            "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1"
          ];
          ExecStart = pkgs.writeShellScript "start-tigervnc" ''
            set -eu

            # Get Tailscale IP for binding, fallback to all interfaces
            iface_ip=""
            if command -v tailscale >/dev/null 2>&1; then
              iface_ip=$(tailscale ip -4 2>/dev/null | grep -m1 . || true)
            fi
            if [ -z "$iface_ip" ]; then
              iface_ip="0.0.0.0"
            fi

            export HOME=${vncHome}
            export USER=${vncUser}
            export LOGNAME=${vncUser}
            export SHELL=${pkgs.fish}/bin/fish
            export LANG=C.UTF-8
            export LC_ALL=C.UTF-8
            export NO_AT_BRIDGE=1
            export XAUTHORITY=${vncHome}/.Xauthority
            export XDG_RUNTIME_DIR=${vncConfigDir}/run
            export XDG_CONFIG_HOME=${vncHome}/.config
            export XDG_SESSION_DESKTOP=xfce
            export XDG_CURRENT_DESKTOP=XFCE
            export XDG_SESSION_TYPE=x11
            export DISPLAY=:1
            export XDG_CONFIG_DIRS=${pkgs.xfce4-session}/etc/xdg:/etc/xdg
            export XDG_DATA_DIRS=${pkgs.xfconf}/share:${pkgs.xfce4-session}/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:/usr/local/share:/usr/share
            export PATH=${
              pkgs.lib.makeBinPath [
                pkgs.coreutils
                pkgs.dbus
                pkgs.xrdb
                pkgs.xfce4-session
                pkgs.xfconf
                pkgs.xfce4-panel
                pkgs.xfce4-terminal
                pkgs.xfdesktop
                pkgs.xfwm4
                pkgs.xfce4-settings
                pkgs.thunar
                pkgs.hicolor-icon-theme
                pkgs.xauth
                pkgs.xinit
                pkgs.tigervnc
                pkgs.xfconf
              ]
            }:$PATH

            rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
            mkdir -p ${vncConfigDir}/run
            chmod 700 ${vncConfigDir}/run

            ${pkgs.tigervnc}/bin/Xvnc :1 -geometry 1920x1080 -depth 24 -rfbport 5901 -interface "$iface_ip" -localhost no -SecurityTypes VncAuth -PasswordFile "${vncConfigDir}/passwd" &

            dbus_info_file=$(mktemp "${vncConfigDir}/run/dbus-session.XXXXXX")
            trap 'rm -f "$dbus_info_file"' EXIT
            ${pkgs.dbus}/bin/dbus-daemon --fork --print-address=1 --print-pid=1 --config-file ${pkgs.dbus}/share/dbus-1/session.conf > "$dbus_info_file"
            IFS= read -r DBUS_SESSION_BUS_ADDRESS < "$dbus_info_file"
            IFS= read -r _DBUS_SESSION_BUS_PID < <(${pkgs.coreutils}/bin/tail -n 1 "$dbus_info_file")
            export DBUS_SESSION_BUS_ADDRESS

            sleep 3
            exec ${pkgs.xfce4-session}/bin/startxfce4
          '';

          ExecStopPost = "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1";
        };
      };
    };

  };
}
