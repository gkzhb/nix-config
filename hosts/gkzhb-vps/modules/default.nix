{ pkgs, ... }:

{
  config = {
    system-manager.allowAnyDistro = true;
    services.system-manager-gc.enable = true;
    nixpkgs.hostPlatform = "x86_64-linux";

    nix = {
      enable = true;
      package = pkgs.nix;
      distributedBuilds = true;
      settings = {
        builders = [ "ssh-ng://zg x86_64-linux" ];
        max-jobs = 0;
        http-connections = 4;
        max-substitution-jobs = 4;
        builders-use-substitutes = true;
        extra-substituters = "https://cache.numtide.com";
        extra-trusted-public-keys = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
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
      mosh
      tmux
      just
      tree-sitter
      btop
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
      nil
      nixfmt
      thrift-ls

      # ai related
      edge.tuios
      edge.pi-coding-agent

      # Secret management CLI tools
      sops
      age

      # server services
      tailscale
      tailscale.derper
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
