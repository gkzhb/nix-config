{ pkgs, self, ... }:
{
  # packages installed in system profile
  environment.systemPackages = with pkgs; [
    nil
    nixfmt
    git
    tmux
    fish
    neovim
    zoxide
    yazi
    zenith
    uv
    nodejs
    bun
    deno
  ];

  # Auto upgrade nix package and the daemon service.
  nix = {
    package = pkgs.nix;
    settings = {
      # "extra-experimental-features" = [ "nix-command" "flakes" ];
      # Necessary for using flakes on this system.
      experimental-features = "nix-command flakes";
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

  users.users.bytedance = {
    name = "bytedance";
    home = "/Users/bytedance";
  };

  imports = [
    ./services.nix
  ];
}
