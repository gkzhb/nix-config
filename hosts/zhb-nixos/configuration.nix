# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

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
    # use local athens
    # impure-env = "GOPROXY=http://localhost:8333,direct";
  };
  systemd.services = {
    # use local athens
    nix-daemon.environment = {
      # GOPROXY = "http://localhost:8333,direct";
      http_proxy = "http://100.64.0.10:10881";
      https_proxy = "http://100.64.0.10:10881";
      no_proxy = "localhost,127.0.0.1,100.64.0.0/10";
    };
  };
  programs = {
    fish = {
      enable = true;
    };
    #   direnv = {
    #   enable = true;
    # };
    # tmux = {
    #   enable = true;
    # };
    neovim = {
      enable = true;
    };
    # mosh.enable = true;
    # yazi.enable = true;
    # npm = {
    # enable = true;
    # npmrc = ''
    #   registry=https://registry.npmmirror.com
    # '';
    # };
    vscode = {
      enable = true;
    };
    localsend.enable = true;
    firefox.enable = true;
    steam = {
      # enable = true;
    };
  };
  services.tailscale.enable = true;

  # ata6 is the WDC mechanical drive; cap its SATA link at 3.0 Gbps.
  boot.kernelParams = [
    "ahci.mobile_lpm_policy=1"
    "libata.force=6:3.0"
  ];
  # Bootloader.
  boot.loader = {
    systemd-boot = {
      enable = false;
      configurationLimit = 5;
    };
    limine = {
      enable = true;
      maxGenerations = 5;
      extraEntries = ''
        /:Windows 11
        comment: Windows 11
        protocol: efi
        path: boot():/EFI/Microsoft/Boot/bootmgfw.efi

        /:Memtest
        comment: MS Memory Test
        protocol: efi
        path: boot():/EFI/Microsoft/Boot/memtest.efi
      '';
    };
    efi.canTouchEfiVariables = true;
    # grub.configurationLimit = 5;
  };

  # Managed swap file on the ext4 root filesystem (32 GiB).
  swapDevices = [
    {
      device = "/swapfile";
      size = 32768; # MiB
    }
  ];

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
  hardware.nvidia = {
    modesetting.enable = true;
    # TU106/Turing: use NVIDIA's proprietary kernel module for DP sound.
    open = false;
  };

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
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
          bbenoist.nix
          ms-python.python
          ms-vscode-remote.remote-ssh
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        ];
    })
    brave
    helium
    kitty
    bitwarden-desktop

    nil
    nixfmt
    xray
    v2raya

  ];
  documentation.nixos.enable = false;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

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
