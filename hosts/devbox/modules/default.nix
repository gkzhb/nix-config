{ pkgs, ... }:

{
  config = {
    system-manager.allowAnyDistro = true;
    nixpkgs.hostPlatform = "x86_64-linux";

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "zhanghaibin.zhb"
      ];
    };

    environment.systemPackages = with pkgs; [
      nix
      fish
      tree-sitter
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
      code-server
      xray
      taskwarrior3
      nil
      nixfmt
      v2raya
      thrift-ls
      chromium
      timewarrior
      taskwarrior-tui
    ];

  };
}
