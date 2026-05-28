{
  pkgs,
  self,
  # codebase-memory-mcp,
  ...
}:
{
  # packages installed in system profile
  environment.systemPackages = with pkgs; [
    # shell tools
    tmux
    fish
    zoxide
    yazi
    zenith
    neovim
    fzf
    fd
    ripgrep
    television

    # devtools
    just
    tree-sitter
    nil
    nixfmt
    git
    uv
    ty
    ruff
    nodejs
    bun
    deno
    thrift-ls

    # proxy
    xray
    # v2raya # not supported

    # todo cli tools
    taskwarrior3
    timewarrior
    taskwarrior-tui
    beads
    # codebase-memory-mcp.packages.${pkgs.system}.default
  ];

  # Auto upgrade nix package and the daemon service.
  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "bytedance"
      ];
    };
  };

  # Enable alternative shell support in nix-darwin.
  programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # Fix nixbld group GID mismatch
  ids.gids.nixbld = 30000;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  security.pam.services.sudo_local.touchIdAuth = true;

  users.users.bytedance = {
    name = "bytedance";
    home = "/Users/bytedance";
  };

  imports = [
    ./services.nix
  ];
}
