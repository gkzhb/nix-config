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

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # networking.hostName = "nixos"; # Define your hostname.

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  sops = {
    defaultSopsFile = ./secrets/db.yaml;
    age = {
      keyFile = "/home/zhb/.config/sops/age/keys.txt";
      generateKey = false;
    };
    secrets = {
      "psql/admin_user" = { };
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.zhb = {
    isNormalUser = true;
    home = "/home/zhb";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
    ];
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      nodejs
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
    gnumake
    lsof

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

    neovim
    wget
    git
    tmux
    zoxide

    nixfmt
    nil
  ];

  # List services that you want to enable:
  services = {
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
        auth.token = "gkzhb-frp";
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
      extraDaemonFlags = [ "--no-logs-no-support" ];
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
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall = {
    enable = true;
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
