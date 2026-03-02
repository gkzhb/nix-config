# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nixpkgs.config.system = "x86_64-linux";
  nixpkgs.config.allowUnsupportedSystem = false;
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 设置 nix 的 trusted-users，允许 zhb 用户无需 sudo 执行 nix 命令
  nix.settings.trusted-users = [
    "root"
    "zhb"
  ];

  # networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  sops = {
    defaultSopsFile = ../../secrets/db.yaml;
    age = {
      keyFile = "/home/zhb/.config/sops/age/keys.txt";
      generateKey = false;
    };
    secrets = {
      "psql/admin_user" = { };
      "node_red/sso_client_id" = { };
      "node_red/sso_client_secret" = { };
      "node_red/http_api_key" = { };
      "frp/auth_token" = { };
      "miniflux/pg-password" = { };
      "miniflux/admin-username" = { };
      "miniflux/admin-password" = { };
      "miniflux/oidc-client-secret" = { };
      "cloudflare/api-key" = { };
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  users.groups.zhb = { };
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.zhb = {
    isNormalUser = true;
    home = "/home/zhb";
    extraGroups = [
      "wheel"
      "docker"
      "zhb"
    ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
    ];
  };

  programs.nix-ld.dev = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      musl
    ];
  };
  programs.fish.enable = true;
  programs.yazi.enable = true;
  programs.npm.enable = true;
  programs.npm.npmrc = ''
    registry=https://registry.npmmirror.com
  '';
  programs.tmux = {
    enable = true;
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    musl
    gnumake
    lsof
    steam-run
    nix-your-shell # use fish inside `niv develop`

    fzf
    fd
    ripgrep
    zenith
    tree-sitter
    nodePackages.pnpm
    # opencode
    # bun # requires AVX CPU instructions
    gcc
    just
    age
    sops
    gnupg
    ssh-to-pgp
    uv
    python312
    mise

    neovim
    wget
    git
    tmux
    zoxide
    docker-compose
    qbittorrent-cli

    ty # python lsp
    ruff # python linter and formatter
    nixfmt
    nil
    # playwright-driver.browsers

    llm-agents.opencode
    llm-agents.agent-browser

    llm-agents.openclaw
    llm-agents.mcporter

    # GUI app
    # kdePackages.sddm-kcm
    # vlc
    # wayland-utils
  ];

  services = {
    envfs = {
      enable = true;
    };
    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    frp = {
      enable = true;
      role = "client";
      settings = {
        serverAddr = "gkzhb.top";
        serverPort = 7000;
        auth.tokenSource.type = "file";
        auth.tokenSource.file.path = "/run/credentials/frp.service/frp_auth_token";
        proxies = [
          {
            name = "ssh";
            type = "tcp";
            localPort = 22;
            remotePort = 4424;
          }
        ];
      };
    };
    tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "server";
      extraDaemonFlags = [ "--no-logs-no-support" ];
      extraUpFlags = [ "--advertise-exit-node" ];
    };
    xray = {
      enable = true;
      settingsFile = "/etc/xray/config.json";
    };
    syncthing = {
      enable = true;
      # group = "mygroupname";
      user = "zhb";
      dataDir = "/home/zhb/syncthing"; # Default folder for new synced folders
      configDir = "/home/zhb/.config/syncthing"; # Folder for Syncthing's settings and keys
      guiAddress = "0.0.0.0:8384";
    };
    # set ddns for ipv6
    godns = {
      enable = true;
      # useless config, login_token_file not working
      settings = {
        provider = "Cloudflare";
        login_token_file = "$CREDENTIALS_DIRECTORY/login_token";
        interval = 300;
        ip_type = "IPv6";
        domains = [
          {
            domain_name = "gkzhb.top";
            sub_domains = [
              "home"
              "h"
              "*.h"
            ];
          }
        ];
      };
    };

    samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = "nixos";
          "netbios name" = "nixos";
          "security" = "user";
          "browseable" = "yes";
          #"use sendfile" = "yes";
          "max protocol" = "smb2";
          # note: localhost is the ipv6 localhost ::1
          "hosts allow" = "192.168.2.0/16 127.0.0.1 localhost";
          # "hosts deny" = "0.0.0.0/0";
          "guest account" = "zhb";
          "map to guest" = "bad user";
        };
        "public" = {
          "path" = "/mnt/data";
          "browseable" = "yes";
          "public" = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "zhb";
          "force group" = "zhb";
        };
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
    node-red = {
      enable = true;
      port = 1880;
      user = "zhb";
      withNpmAndGcc = true; # Allow imperative download of nodes. Need to enable nix-ld, see below
      configFile = ./node-red/settings.js;
      userDir = "/mnt/data/nodered/data";
    };

    postgresql = {
      enable = true;
      # manually set db version
      package = pkgs.postgresql_18;
      ensureDatabases = [ "miniflux" ];
      ensureUsers = [
        {
          name = "miniflux";
          ensureDBOwnership = true;
        }
      ];
      enableTCPIP = true;
      # port = 5432;
      extensions = with pkgs.postgresql18Packages; [ pgvector ];
      authentication = pkgs.lib.mkOverride 10 ''
        #type database  DBuser  auth-method
        local all       all     trust
        # ipv4
        host  all      all     127.0.0.1/32   trust
        # ipv6
        host all       all     ::1/128        trust
      '';
    };

    qbittorrent = {
      enable = true;
      webuiPort = 8051;
      user = "zhb";
      profileDir = "/mnt/data/qbittorrent";
      serverConfig = {
        Preferences = {
          General = {
            Locale = "zh_CN";
            SavePath = "/mnt/data/transmission";
          };
          WebUI = {
            AlternativeUIEnabled = true;
            RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
            Username = "zhb";
            Password_PBKDF2 = "@ByteArray(4O9mQMfIWzaA2NkMQMPkmw==:H6ltTYPekYs2Y8hS46tV/dv4tHyizOceyIsBgDUl/gAzNSVpMZHnXIUxfS0UT4+iEqANcRiNIAZOlbeKhgckDw==)";
          };
          # seems not working in webui
          BitTorrent = {
            Session.DefaultSavePath = "/mnt/data/transmission";
            Session.PeXEnabled = false;
          };
        };
      };
    };

    minifluxng = {
      enable = true;
      baseUrl = "https://read.gkzhb.top";
      listenAddress = "0.0.0.0:8050";
      enableOidc = true;
      oidcClientId = "PBAkbEhUMwPlcd8r2pZtdtui7TGlSHmd4awPALSh";
      oidcRedirectUrl = "https://miniflux.gkzhb.top/oauth2/oidc/callback";
      oidcDiscoveryEndpoint = "https://sso.gkzhb.top/application/o/miniflux/";
      enableOidcUserCreation = true;
    };

    # GUI env
    # Enable the KDE Plasma 6 Desktop Environment.
    # displayManager = {
    #   sddm.enable = true;
    #   sddm.wayland.enable = true;
    # };
    # desktopManager.plasma6.enable = true;
    # # Enable the X11 windowing system.
    # xserver = {
    #   enable = true;
    #   # Configure keymap in X11
    #   xkb = {
    #     layout = "us";
    #     variant = "";
    #   };
    #   # Enable touchpad support (enabled default in most desktopManager).
    #   # libinput.enable = true;
    # };
  };

  systemd.services = {
    godns = {
      serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.godns}/bin/godns -c /etc/godns/config.yaml";
        LoadCredential = [
          "login_token:${config.sops.secrets."cloudflare/api-key".path}"
        ];
      };
    };
    postgresql-init-miniflux-password = {
      description = "Set PostgreSQL miniflux user password from sops-nix";
      after = [
        "postgresql.service"
        "sops-nix.service"
      ];
      requires = [
        "postgresql.service"
        "sops-nix.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        ExecStart = pkgs.writeShellScript "init-miniflux-password" ''
          PASSWORD=$(cat ${config.sops.secrets."miniflux/pg-password".path})
          ${pkgs.postgresql_18}/bin/psql -c "ALTER USER miniflux WITH PASSWORD '$PASSWORD';"
        '';
      };
    };
    node-red = {
      path = with pkgs; [
        musl
        # git is needed for projects, but systemd resets the path so we need to add it back
        git
        # needed by nodejs to install for instance node-red-dashboard (or "error syscall spawn sh")
        bash
        fish
      ];
      environment = {
        # environment variables are removed, so we need to specify nix-ld environment here
        NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
        # load npm dependencies ("passport-openidconnect")
        NODE_PATH = "/mnt/data/nodered/data/node_modules";
        NIX_LD_LIBRARY_PATH =
          with pkgs;
          lib.makeLibraryPath [
            # List by default
            zlib
            zstd
            stdenv.cc.cc
            curl
            openssl
            attr
            libssh
            bzip2
            libxml2
            acl
            libsodium
            util-linux
            xz
            systemd
          ];
        # fix loading sqlite nodes, which requires musl lib
        LD_LIBRARY_PATH = "${pkgs.musl}/lib";
      };
      serviceConfig = {
        LoadCredential = [
          "sso_client_id:${config.sops.secrets."node_red/sso_client_id".path}"
          "sso_client_secret:${config.sops.secrets."node_red/sso_client_secret".path}"
          "http_api_key:${config.sops.secrets."node_red/http_api_key".path}"
        ];
      };
    };
    frp = {
      serviceConfig = {
        LoadCredential = [
          "frp_auth_token:${config.sops.secrets."frp/auth_token".path}"
        ];
      };
    };
    docker = {
      environment = {
        # set network proxy to fetch images
        HTTP_PROXY = "http://localhost:10881";
        HTTPS_PROXY = "http://localhost:10881";
        NO_PROXY = "localhost,127.0.0.1,.example.com";
      };
    };
  };

  # Enable the Docker service
  virtualisation.docker.enable = true;

  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    # Only allow specific ports from external sources
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      443 # HTTPS
    ];
    # Allow Tailscale sources full access
    trustedInterfaces = [ "tailscale0" ];
    # Allow LAN traffic (common private IP ranges)
    extraCommands = ''
      iptables -A nixos-fw -s 192.168.1.0/16 -j nixos-fw-accept
      iptables -A nixos-fw -s 100.64.0.0/8 -j nixos-fw-accept
    '';
    # Clean up rules when firewall stops
    extraStopCommands = ''
      iptables -D nixos-fw -s 192.168.1.0/16 -j nixos-fw-accept 2>/dev/null || true
      iptables -D nixos-fw -s 100.64.0.0/8 -j nixos-fw-accept 2>/dev/null || true
    '';
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
