{ pkgs, ... }:

{
  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = "x86_64-linux";

    nix = {
      enable = true;
      package = pkgs.nix;
      settings = {
        builders = [ "ssh-ng://zg x86_64-linux" ];
        max-jobs = 0;
        builders-use-substitutes = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "zhb"
        ];
      };
    };

    users = {
      groups.nginx = { };

      users.nginx = {
        isSystemUser = true;
        group = "nginx";
      };
    };

    environment.systemPackages = with pkgs; [
      system-manager
      git
      fish
      tmux
      just
      tree-sitter
      zenith
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
      xray
      taskwarrior3
      nil
      nixfmt
      thrift-ls
      timewarrior
      taskwarrior-tui

      # server services
      tailscale
      frp
    ];

    # logrotate config for xray logs
    environment.etc."logrotate.d/xray".text = ''
      /var/log/xray/*.log {
          daily
          rotate 7
          missingok
          notifempty
          compress
          delaycompress
          copytruncate
      }
    '';

    services = {
      nginx = {
        enable = true;

        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        recommendedGzipSettings = true;

        appendHttpConfig = ''
          include /etc/nginx/conf.d/*.conf;
        '';
      };
    };

  };
}
