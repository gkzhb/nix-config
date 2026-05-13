{ pkgs, ... }:

let
  vncUser = "zhanghaibin.zhb";
  vncHome = "/home/${vncUser}";
  vncRuntimeDir = "tigervnc-zhanghaibin-zhb";
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
      fish
      tmux
      zenith
      just
      tree-sitter
      fzf
      fd
      neovim
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
      xauth
      xinit
      firefox
      brave
    ];

    environment.etc."tigervnc/xstartup".source = pkgs.writeShellScript "tigervnc-xstartup" ''
      exec >"$HOME/.vnc/xstartup.log" 2>&1

      export PATH=${pkgs.lib.makeBinPath [
        pkgs.coreutils
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
      ]}:$PATH
      export HOME=${vncHome}
      export USER=${vncUser}
      export LOGNAME=${vncUser}
      export SHELL=${pkgs.fish}/bin/fish
      export XDG_SESSION_DESKTOP=xfce
      export XDG_CURRENT_DESKTOP=XFCE
      export XDG_SESSION_TYPE=x11
      export XDG_CONFIG_DIRS=${pkgs.xfce4-session}/etc/xdg:/etc/xdg
      export XDG_RUNTIME_DIR=/run/${vncRuntimeDir}
      export XDG_DATA_DIRS=${pkgs.xfce4-session}/share:${pkgs.xfce4-panel}/share:${pkgs.xfdesktop}/share:${pkgs.xfwm4}/share:${pkgs.xfce4-settings}/share:${pkgs.hicolor-icon-theme}/share:$XDG_DATA_DIRS

      echo "=== Starting TigerVNC XFCE session $(date -Is) ==="
      exec ${pkgs.xfce4-session}/bin/xfce4-session
    '';

    systemd.services.tigervnc = {
      description = "TigerVNC server";
      wantedBy = [ "system-manager.target" ];
      after = [ "network.target" ];
      path = with pkgs; [
        coreutils
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
        xinit
        xrdb
      ];
      serviceConfig = {
        Type = "simple";
        User = vncUser;
        Group = vncUser;
        WorkingDirectory = vncHome;
        Restart = "on-failure";
        RestartSec = "5s";
        RuntimeDirectory = vncRuntimeDir;
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        KillMode = "mixed";
        TimeoutStopSec = "30s";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -m 700 ${vncHome}/.vnc"
          "${pkgs.coreutils}/bin/test -f ${vncHome}/.vnc/passwd"
          "${pkgs.coreutils}/bin/touch ${vncHome}/.vnc/xstartup.log"
          "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1"
        ];
        ExecStart = pkgs.writeShellScript "start-tigervnc" ''
          set -eu

          export HOME=${vncHome}
          export USER=${vncUser}
          export LOGNAME=${vncUser}
          export SHELL=${pkgs.fish}/bin/fish
          export XAUTHORITY=${vncHome}/.Xauthority
          export XDG_RUNTIME_DIR=/run/${vncRuntimeDir}

          exec ${pkgs.xinit}/bin/xinit /etc/tigervnc/xstartup -- \
            ${pkgs.tigervnc}/bin/Xvnc :1 \
            -geometry 1920x1080 \
            -depth 24 \
            -rfbport 5901 \
            -localhost no \
            -SecurityTypes VncAuth \
            -PasswordFile ${vncHome}/.vnc/passwd
        '';
        ExecStopPost = "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1";
      };
    };

  };
}
