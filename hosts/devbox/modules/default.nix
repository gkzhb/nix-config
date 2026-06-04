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

    systemd.services.tigervnc = {
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

                        # Create dbus session.d listen config in user's home dir
                        mkdir -p "${vncConfigDir}/dbus-1/session.d"
                        cat > "${vncConfigDir}/dbus-1/session.d/listen.conf" <<'EODBUS'
            <busconfig>
              <listen>unix:tmpdir=/run</listen>
              <fork>true</fork>
            </busconfig>
            EODBUS
          '')
          "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1"
        ];
        ExecStart = pkgs.writeShellScriptBin "start-tigervnc" ''
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
          export XDG_DATA_DIRS=${pkgs.xfce4-session}/share:${pkgs.xfce4-panel}/share:${pkgs.xfdesktop}/share:${pkgs.xfwm4}/share:${pkgs.xfce4-settings}/share:${pkgs.hicolor-icon-theme}/share
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
            ]
          }:$PATH

          # Clean up any stale lock files
          rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

          # Create runtime directory in user-writable location (not /run which is owned by systemd)
          mkdir -p ${vncConfigDir}/run
          chmod 700 ${vncConfigDir}/run

          # Start Xvnc in background
          ${pkgs.tigervnc}/bin/Xvnc :1 -geometry 1920x1080 -depth 24 -rfbport 5901 -interface "$iface_ip" -localhost no -SecurityTypes VncAuth -PasswordFile "${vncConfigDir}/passwd" &

          # Wait for Xvnc to initialize
          sleep 3

          # Start dbus session with xfce4-session
          # dbus-run-session handles session bus setup properly
          ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.xfce4-session}/bin/xfce4-session &

          # Keep the script running while xfce4-session is alive
          wait
        '';
        ExecStopPost = "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1";
      };
    };

  };
}
