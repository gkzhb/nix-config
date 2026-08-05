{ pkgs, ... }:

{
  config = {
    # postmarketOS is Alpine-derived, so it is outside system-manager's
    # supported distro set. This host has systemd as PID 1, which is required
    # by system-manager, but its system integration remains intentionally
    # limited to the global Nix package environment below.
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = "aarch64-linux";

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
          "user"
          "root"
        ];
      };
    };

    # The apk-provided nix-daemon and /etc/nix/nix.conf remain host-managed.
    # Do not set nix.* here: system-manager would otherwise take ownership of
    # host Nix configuration files.

    environment.systemPackages = with pkgs; [
      # Start with small, cache-friendly CLI tools. Add all globally exposed
      # Nix packages here; they appear through /run/system-manager/sw/bin.
      system-manager
      bat
      fd
      fish
      fzf
      git
      just
      neovim
      ripgrep
      tmux
      yazi
      zoxide
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
