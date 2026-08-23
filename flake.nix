{
  description = "gkzhb's flake";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    minifluxng.url = "github:gkzhb/miniflux.nix";
    minifluxng.inputs.nixpkgs.follows = "nixpkgs";

    hermes-agent.url = "github:NousResearch/hermes-agent";

    helium-flake.url = "github:oxcl/nix-flake-helium-browser";
    helium-flake.inputs.nixpkgs.follows = "nixpkgs";

    # buggy program
    # codebase-memory-mcp.url = "github:DeusData/codebase-memory-mcp";
    # codebase-memory-mcp.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nix-ld,
      vscode-server,
      nixpkgs,
      home-manager,
      sops-nix,
      llm-agents,
      minifluxng,
      hermes-agent,
      helium-flake,
      # codebase-memory-mcp,
      system-manager,
      nix-darwin,
      treefmt-nix,
      git-hooks,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      formatterSystems = systems ++ [
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllFormatterSystems = nixpkgs.lib.genAttrs formatterSystems;
      treefmtEval = forAllFormatterSystems (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );
      gitHooks = forAllFormatterSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          treefmt-stage = pkgs.writeShellApplication {
            name = "treefmt-stage";
            runtimeInputs = [
              pkgs.git
              treefmtEval.${system}.config.build.wrapper
            ];
            text = ''
              treefmt "$@"
              git add -- "$@"
            '';
          };
        in
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks.treefmt-stage = {
            enable = true;
            name = "treefmt-stage";
            entry = "${treefmt-stage}/bin/treefmt-stage";
            files = "\\.nix$";
            pass_filenames = true;
            require_serial = true;
          };
        }
      );
      llm-agents-overlay = final: prev: {
        llm-agents = llm-agents.packages.${prev.stdenv.hostPlatform.system} or { };
      };
      # Local package overlay for mmx-cli
      local-packages = import ./packages;
    in
    {
      formatter = forAllFormatterSystems (system: treefmtEval.${system}.config.build.wrapper);

      checks = forAllFormatterSystems (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      devShells = forAllFormatterSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = gitHooks.${system}.enabledPackages;
            shellHook = gitHooks.${system}.shellHook;
          };
        }
      );

      nixosConfigurations = {
        home-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nix-ld.nixosModules.nix-ld
            vscode-server.nixosModules.default

            {
              nixpkgs.overlays = [
                llm-agents.overlays.shared-nixpkgs
                local-packages
              ];
            }
            hermes-agent.nixosModules.default
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
        zhb-nixos = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            # nix-ld.nixosModules.nix-ld
            ./hosts/zhb-nixos/configuration.nix
            {
              nixpkgs.overlays = [
                llm-agents.overlays.shared-nixpkgs
                helium-flake.overlays.default
              ];
            }
            # home-manager.nixosModules.home-manager
            # {
            #   home-manager.useGlobalPkgs = true;
            #   home-manager.useUserPackages = true;
            #   home-manager.users.zhb = ./hosts/home-nixos/user.nix;
            #
            #   # Optionally, use home-manager.extraSpecialArgs to pass
            #   # arguments to home.nix
            # }
            # sops-nix.nixosModules.sops
          ];
        };
      };

      systemConfigs = {
        mido = system-manager.lib.makeSystemConfig {
          modules = [
            ./hosts/mido/modules/default.nix
          ];
        };
        devbox = system-manager.lib.makeSystemConfig {
          modules = [
            { nixpkgs.overlays = [ llm-agents-overlay ]; }
            ./hosts/devbox/modules/default.nix
          ];
        };
        "gkzhb-vps" = system-manager.lib.makeSystemConfig {
          modules = [
            ./hosts/gkzhb-vps/modules/default.nix
            ./hosts/gkzhb-vps/modules/systemd.nix
          ];
        };
      };

      homeConfigurations = {
        # for devbox user
        "zhanghaibin.zhb" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/devbox/user.nix ];
        };

        "zhb" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [ ./hosts/gkzhb-vps/user.nix ];
        };
      };
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#gkzhb-MBP-6
      packages = nixpkgs.lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              llm-agents-overlay
              local-packages
            ];
          };
        in
        {
          inherit (pkgs) mmx-cli;
          default = pkgs.mmx-cli;
        }
      );

      darwinConfigurations = {
        "gkzhb-MBP" = nix-darwin.lib.darwinSystem {
          modules = [
            {
              nixpkgs.overlays = [
                llm-agents-overlay
                local-packages
              ];
            }
            ./hosts/gkzhb-mbp/configuration.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.bytedance = ./hosts/gkzhb-mbp/user.nix;

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
          ];
          specialArgs = {
            inherit self; # codebase-memory-mcp;
          };
        };
      };
    };
}
