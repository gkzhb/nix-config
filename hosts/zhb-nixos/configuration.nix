# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

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

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      # "configurable-impure-env"
    ];
    trusted-users = [
      "root"
      "zhb"
    ];
  };
  systemd.services = {
    # use local athens
    nix-daemon.environment = {
      # GOPROXY = "http://localhost:8333,direct";
      http_proxy = "http://localhost:10881";
      https_proxy = "http://localhost:10881";
      no_proxy = "localhost,127.0.0.1,192.168.0.0/16,100.64.0.0/10";
    };
  };
  programs = {
    nix-ld.dev = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        musl
      ];
    };
    fish = {
      enable = true;
    };
    direnv = {
      enable = true;
    };
    tmux = {
      enable = true;
    };
    neovim = {
      enable = true;
    };
    mosh.enable = true;
    yazi.enable = true;
    npm = {
      enable = true;
      npmrc = ''
        registry=https://registry.npmmirror.com
      '';
    };
    vscode = {
      enable = true;
    };
    localsend.enable = true;
    firefox.enable = true;
    steam = {
      enable = true;
    };
  };
  services = {
    tailscale.enable = true;
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PubkeyAuthentication = true;
        AuthenticationMethods = "publickey";
        MaxAuthTries = 3;
        PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
        AllowUsers = [ "zhb" ];
      };
    };

    v2raya = {
      enable = true;
      cliPackage = pkgs.xray;
    };
    qbittorrent = {
      enable = true;
      # package = pkgs.qbittorrent-enhanced;
      user = "zhb";
      group = "users";
      # Keep the existing per-user qBittorrent state in $HOME.
      profileDir = "/home/zhb/.local/share/qBittorrent";
      serverConfig = {
        BitTorrent.Session.DefaultSavePath = "/mnt/data/Windows/Downloads/qbittorrent";
      };
      openFirewall = true;
    };
  };

  # The upstream qBittorrent module hardens the service with ProtectHome=yes
  # and PrivateUsers=true. Both prevent a service using zhb's profile in $HOME
  # from accessing that profile and cause qbittorrent-enhanced to abort at startup.
  systemd.services.qbittorrent.serviceConfig = {
    ProtectHome = lib.mkForce false;
    PrivateUsers = lib.mkForce false;
  };

  networking.hostName = "zhb-nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "zh_CN.UTF-8";
      LC_IDENTIFICATION = "zh_CN.UTF-8";
      LC_MEASUREMENT = "zh_CN.UTF-8";
      LC_MONETARY = "zh_CN.UTF-8";
      LC_NAME = "zh_CN.UTF-8";
      LC_NUMERIC = "zh_CN.UTF-8";
      LC_PAPER = "zh_CN.UTF-8";
      LC_TELEPHONE = "zh_CN.UTF-8";
      LC_TIME = "zh_CN.UTF-8";
    };

    inputMethod = {
      type = "fcitx5";
      enable = true;
      fcitx5 = {
        waylandFrontend = true;
        addons = with pkgs; [
          fcitx5-rime
        ];
      };
    };
  };

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji

      # nerd fonts
      nerd-fonts.fira-code
      nerd-fonts.droid-sans-mono
    ];
    # fontconfig.defaultFonts = {
    #   sansSerif = [
    #     "Noto Sans CJK SC"
    #     "Noto Sans"
    #   ];
    #   serif = [
    #     "Noto Serif CJK SC"
    #     "Noto Serif"
    #   ];
    #   monospace = [
    #     "Noto Sans Mono CJK SC"
    #     "Noto Sans Mono"
    #   ];
    #   emoji = [ "Noto Color Emoji" ];
    # };
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Use the proprietary NVIDIA driver for the TU106 GPU rather than nouveau.
  # Kernel modesetting is required for a reliable Plasma Wayland session.
  services.xserver.videoDrivers = [ "nvidia" ];

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "cn";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define user accounts
  users.users."zhb" = {
    isNormalUser = true;
    description = "zhb";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [
      kdePackages.kate
      #  thunderbird
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    ntfs3g
    p7zip # provides 7z; supports extracting RAR archives
    pciutils
    usbutils
    smartmontools

    neovim
    git
    fish
    zenith
    tmux
    curl
    jq
    zoxide
    yazi
    fzf
    fd
    ripgrep
    television
    wget
    just
    optnix

    # AI
    llm-agents.pi

    # GUI apps
    (vscode-with-extensions.override {
      vscodeExtensions =
        with vscode-extensions;
        [
          alefragnani.project-manager
          jnoortheen.nix-ide
          ms-vscode-remote.remote-ssh
          asvetliakov.vscode-neovim

        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        ];
    })
    brave
    helium
    kitty
    bitwarden-desktop
    vlc

    nil
    nixfmt
  ];
  documentation.nixos.enable = false;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.11"; # Did you read the comment?

}
