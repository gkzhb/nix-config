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

  nixpkgs.config = {
    system = "x86_64-linux";
    allowUnsupportedSystem = false;
    allowUnfreePredicate =
      pkg:
      builtins.elem (lib.getName pkg) [
        "steam"
        "steam-unwrapped"
      ];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "configurable-impure-env"
    ];
    # 设置 nix 的 trusted-users，允许 zhb 用户无需 sudo 执行 nix 命令
    trusted-users = [
      "root"
      "zhb"
    ];
    # use local athens
    impure-env = "GOPROXY=http://localhost:8333,direct";
  };

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
    templates."telegraf-influxdb2.env" = {
      owner = "telegraf";
      group = "telegraf";
      mode = "0400";
      content = ''
        INFLUX_TOKEN=${config.sops.placeholder."influxdb2/telegraf_token"}
      '';
    };
    templates."grafana-influxdb2-token" = {
      owner = "grafana";
      group = "grafana";
      mode = "0400";
      content = ''
        ${config.sops.placeholder."influxdb2/grafana_token"}
      '';
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
      "influxdb2/admin_password" = {
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0440";
      };
      "influxdb2/admin_token" = {
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0440";
      };
      "influxdb2/telegraf_token" = {
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0440";
      };
      "influxdb2/grafana_token" = {
        owner = "influxdb2";
        group = "influxdb2";
        mode = "0440";
      };
      "grafana/env" = {
        sopsFile = ../../secrets/grafana.yaml;
        key = "env";
      };
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [
        "Noto Sans CJK SC"
        "Noto Sans"
      ];
      serif = [
        "Noto Serif CJK SC"
        "Noto Serif"
      ];
      monospace = [
        "Noto Sans Mono CJK SC"
        "Noto Sans Mono"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

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
  programs.direnv = {
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
    pnpm
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

    pandoc
    neovim
    wget
    git
    tmux
    zoxide
    docker-compose
    qbittorrent-cli
    taskwarrior3
    taskwarrior-tui
    timewarrior
    nginx # required by deer-flow
    influxdb2
    telegraf

    ty # python lsp
    ruff # python linter and formatter
    nixfmt
    nil
    # playwright-driver.browsers

    llm-agents.pi
    llm-agents.opencode
    llm-agents.claude-code
    # llm-agents.codex
    llm-agents.agent-browser

    # llm-agents.openclaw
    llm-agents.mcporter

    # GUI app
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
    xinit
    firefox
    brave
    # kdePackages.sddm-kcm
    # vlc
    # wayland-utils
  ];

  environment.etc."tigervnc/xstartup".source = pkgs.writeShellScript "tigervnc-xstartup" ''
    exec >"$HOME/.vnc/xstartup.log" 2>&1

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
      ]
    }:$PATH
    export HOME=/home/zhb
    export USER=zhb
    export LOGNAME=zhb
    export SHELL=${pkgs.fish}/bin/fish
    export XDG_SESSION_DESKTOP=xfce
    export XDG_CURRENT_DESKTOP=XFCE
    export XDG_SESSION_TYPE=x11
    export XDG_CONFIG_DIRS=${pkgs.xfce4-session}/etc/xdg:/etc/xdg
    export XDG_RUNTIME_DIR=/run/tigervnc-zhb
    export XDG_DATA_DIRS=${pkgs.xfce4-session}/share:${pkgs.xfce4-panel}/share:${pkgs.xfdesktop}/share:${pkgs.xfwm4}/share:${pkgs.xfce4-settings}/share:${pkgs.hicolor-icon-theme}/share:$XDG_DATA_DIRS

    echo "=== Starting TigerVNC XFCE session $(date -Is) ==="
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.xfce4-session}/bin/xfce4-session
  '';

  services = {
    envfs = {
      enable = true;
    };
    # cache go module downloads
    athens = {
      enable = true;
      port = 8333;
      downloadMode = "async_redirect";
      downloadURL = "https://goproxy.cn";
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
      instances.default = {
        enable = true;
        role = "client";
        settings = {
          serverAddr = "gkzhb.top";
          serverPort = 7000;
          auth.tokenSource.type = "file";
          auth.tokenSource.file.path = "/run/credentials/frp-default.service/frp_auth_token";
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

    influxdb2 = {
      enable = true;
      settings = {
        "http-bind-address" = "0.0.0.0:8086";
        "reporting-disabled" = true;
      };
      provision = {
        enable = true;
        initialSetup = {
          organization = "home";
          bucket = "telegraf";
          username = "admin";
          passwordFile = config.sops.secrets."influxdb2/admin_password".path;
          tokenFile = config.sops.secrets."influxdb2/admin_token".path;
        };
        organizations.home = {
          auths = {
            telegraf = {
              description = "Telegraf write token";
              writeBuckets = [ "telegraf" ];
              tokenFile = config.sops.secrets."influxdb2/telegraf_token".path;
            };
            grafana = {
              description = "Grafana read token";
              readBuckets = [ "telegraf" ];
              tokenFile = config.sops.secrets."influxdb2/grafana_token".path;
            };
          };
        };
      };
    };

    telegraf = {
      enable = true;
      environmentFiles = [ config.sops.templates."telegraf-influxdb2.env".path ];
      extraConfig = {
        agent = {
          interval = "10s";
          round_interval = true;
          metric_batch_size = 1000;
          metric_buffer_limit = 10000;
          flush_interval = "10s";
          hostname = "home-nixos";
        };
        outputs.influxdb_v2 = {
          urls = [ "http://127.0.0.1:8086" ];
          token = "$INFLUX_TOKEN";
          organization = "home";
          bucket = "telegraf";
        };
        inputs = {
          cpu = {
            percpu = true;
            totalcpu = true;
            collect_cpu_time = false;
            report_active = false;
          };
          mem = { };
          disk = {
            ignore_fs = [
              "tmpfs"
              "devtmpfs"
              "devfs"
              "overlay"
              "squashfs"
              "nsfs"
            ];
          };
          diskio = { };
          net = { };
          system = { };
          processes = { };
        };
      };
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

    gatus = {
      enable = true;
      # port 8756
      configFile = "/var/lib/gatus/config.yaml";
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

    grafana = {
      enable = true;
      settings = {
        server = {
          # Listening Address
          http_addr = "0.0.0.0";
          # and Port
          http_port = 8749;
          protocol = "http";
          # Grafana needs to know on which domain and URL it's running
          domain = "grafana.gkzhb.top";
          root_url = "https://grafana.gkzhb.top/";
        };
        # admin_password / secret_key 通过 EnvironmentFile 注入
        security = {
          admin_user = "admin";
          admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
          secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "InfluxDB2-telegraf";
              uid = "influxdb2-telegraf";
              type = "influxdb";
              access = "proxy";
              url = "http://127.0.0.1:8086";
              isDefault = true;
              editable = true;
              jsonData = {
                version = "Flux";
                organization = "home";
                defaultBucket = "telegraf";
              };
              secureJsonData = {
                token = "$__file{${config.sops.templates."grafana-influxdb2-token".path}}";
              };
            }
          ];
        };
      };
    };

    minifluxng = {
      enable = true;
      baseUrl = "https://miniflux.gkzhb.top";
      listenAddress = "0.0.0.0:8050";
      enableOidc = true;
      oidcClientId = "PBAkbEhUMwPlcd8r2pZtdtui7TGlSHmd4awPALSh";
      oidcRedirectUrl = "https://miniflux.gkzhb.top/oauth2/oidc/callback";
      oidcDiscoveryEndpoint = "https://sso.gkzhb.top/application/o/miniflux/";
      enableOidcUserCreation = true;
    };

    hermes-agent = {
      enable = true;
      extraDependencyGroups = [
        "anthropic"
        "feishu"
        "matrix"
      ];
      extraPythonPackages = with pkgs.python312Packages; [ aiohttp ];

      # .hermes/config.yaml
      settings = {
        model = {
          default = "gpt-5.4";
          provider = "custom:NewAPI";
          context_length = 250000;
        };
        custom_providers = [
          {
            name = "NewAPI";
            model = "gpt-5.4";
            base_url = "http://localhost:8056";
            key_env = "NEWAPI_API_KEY";
            api_mode = "anthropic_messages";
          }
        ];
        group_sessions_per_user = false;
        platforms = {
          qqbot = {
            enabled = true;
            extra = {
              markdown_support = true;
              dm_policy = "open";
              group_policy = "open";
            };
          };
          feishu = {
            extra = {
              default_group_policy = "admin_only";
              admins = [ "ou_17408acacef02572c681dc5043e98191" ];
            };
          };
        };
        display = {
          language = "zh";
          tool_progress = "all";
        };
        approvals = {
          mode = "smart";
        };
        browser = {
          cdp_url = "http://localhost:9222";
        };
        compression = {
          threshold = 0.8;
          target_ratio = 0.15;
          protect_last_n = 5;
        };
        # 辅助工具
        auxiliary = {
          vision = {
            provider = "custom:NewAPI";
            model = "gpt-5.4";
          };
          web_extract = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
          approval = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
          compression = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
          skills_hub = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
          mcp = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
          triage_specifier = {
            provider = "custom:NewAPI";
            model = "MiniMax-M3";
          };
        };
        dashboard = {
          oauth = {
            provider = "self-hosted";
          };
        };
      };

      environmentFiles = [ "/home/zhb/.config/hermes/env" ];
      addToSystemPackages = true;
    };

    # push notification service
    ntfy-sh = {
      enable = true;
      user = "zhb";
      group = "zhb";
      environmentFile = "/mnt/data/ntfy/.env";
      settings = {
        base-url = "https://ntfy.gkzhb.top";
        listen-http = "0.0.0.0:9248";
        behind-proxy = true;
        enable-login = true;
        require-login = true;

        # 持久化消息缓存，否则默认内存缓存重启会丢
        cache-file = "/mnt/data/ntfy/cache-file.db";
        cache-duration = "12h";

        # 附件存储；如果不用附件可以不管，但 NixOS 默认也配置了
        attachment-cache-dir = "/mnt/data/ntfy/attachments";
        attachment-total-size-limit = "5G";
        attachment-file-size-limit = "15M";

        # 开启认证数据库
        auth-file = "/mnt/data/ntfy/user.db";

        # 私有实例强烈建议：默认拒绝匿名读写
        auth-default-access = "deny-all";
      };
    };
    # matrix chat server
    matrix-continuwuity = {
      enable = true;
      settings = {
        global = {
          server_name = "matrix.gkzhb.top";
          address = [ "100.64.0.13" ];
          port = [ 9246 ];
          well_known = {
            # defaults to port :443 if not specified
            client = "https://matrix.gkzhb.top";
            # port number MUST be specified
            server = "matrix.gkzhb.top:443";

            support_role = "m.role.admin";
            support_mxid = "@gkzhb:matrix.gkzhb.top";
          };

          allow_registration = true;
          login_via_existing_session = true;
          # You can add any further configuration here, e.g.
          # trusted_servers = [ "matrix.org" ];
        };
      };
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
    # use local athens
    nix-daemon.environment.GOPROXY = "http://localhost:8333,direct";

    godns = {
      serviceConfig = {
        ExecStart = lib.mkForce "${pkgs.godns}/bin/godns -c /etc/godns/config.yaml";
        LoadCredential = [
          "login_token:${config.sops.secrets."cloudflare/api-key".path}"
        ];
      };
    };
    grafana = {
      serviceConfig = {
        EnvironmentFile = config.sops.secrets."grafana/env".path;
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
    frp-default = {
      serviceConfig = {
        LoadCredential = [
          "frp_auth_token:${config.sops.secrets."frp/auth_token".path}"
        ];
      };
    };
    ntfy-sh = {
      serviceConfig = {
        ReadWritePaths = [ "/mnt/data/ntfy" ];
        DynamicUser = lib.mkForce false;
      };
    };
    gatus = {
      serviceConfig = {
        StateDirectory = "gatus";
      };
    };
    tigervnc-zhb = {
      description = "TigerVNC server for zhb";
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        coreutils
        gnugrep
        gnused
        procps
        tailscale
        tigervnc
        dbus
        xauth
        xinit
        xfce4-session
        xfconf
        xfce4-panel
        xfce4-terminal
        xfdesktop
        xfwm4
        xfce4-settings
        thunar
        xrdb
        hicolor-icon-theme
      ];
      serviceConfig = {
        Type = "simple";
        User = "zhb";
        Group = "zhb";
        WorkingDirectory = "/home/zhb";
        Restart = "on-failure";
        RestartSec = "5s";
        RuntimeDirectory = "tigervnc-zhb";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        KillMode = "mixed";
        TimeoutStopSec = "30s";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/install -d -m 700 /home/zhb/.vnc"
          "${pkgs.coreutils}/bin/test -f /home/zhb/.vnc/passwd"
          "${pkgs.coreutils}/bin/touch /home/zhb/.vnc/xstartup.log"
          "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1"
        ];
        ExecStart = pkgs.writeShellScript "start-tigervnc-zhb" ''
          set -eu

          interface_ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | ${pkgs.gnugrep}/bin/grep -m1 . || true)"
          if [ -z "$interface_ip" ]; then
            interface_ip="127.0.0.1"
          fi

          export HOME=/home/zhb
          export USER=zhb
          export LOGNAME=zhb
          export SHELL=${pkgs.fish}/bin/fish
          export XAUTHORITY=/home/zhb/.Xauthority
          export XDG_RUNTIME_DIR=/run/tigervnc-zhb

          exec ${pkgs.xinit}/bin/xinit /etc/tigervnc/xstartup -- \
            ${pkgs.tigervnc}/bin/Xvnc :1 \
            -geometry 1920x1080 \
            -depth 24 \
            -rfbport 5901 \
            -interface "$interface_ip" \
            -localhost no \
            -SecurityTypes VncAuth \
            -PasswordFile /home/zhb/.vnc/passwd
        '';
        ExecStopPost = "${pkgs.coreutils}/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1";
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
  # Temporarily disable this to fix python3.12 build error
  # https://github.com/NixOS/nixpkgs/issues/499166
  documentation.doc.enable = false;

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
  system = {
    stateVersion = "25.11"; # Did you read the comment?
    activationScripts = {
      gatusConfig = ''
        install -d -m 0755 /var/lib/gatus
        install -m 0644 /home/zhb/.config/gatus/config.yaml /var/lib/gatus/config.yaml
      '';
    };
  };

}
