{
  description = "gkzhb's flake";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    minifluxng.url = "git+https://git.sr.ht/~bwolf/miniflux.nix";
    minifluxng.inputs.nixpkgs.follows = "nixpkgs";

    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      self,
      nix-ld,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      sops-nix,
      llm-agents,
      minifluxng,
      system-manager,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      nixosConfigurations = {
        home-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nix-ld.nixosModules.nix-ld

            { nixpkgs.overlays = [ llm-agents.overlays.default ]; }
            ./hosts/home-nixos/configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.zhb = ./hosts/home-nixos/user.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
            sops-nix.nixosModules.sops
            minifluxng.nixosModules.minifluxng
          ];
        };
      };

      systemConfigs = {
        devbox = system-manager.lib.makeSystemConfig {
          modules = [
            ./hosts/devbox/modules/default.nix
          ];
        };
      };
    };
}
