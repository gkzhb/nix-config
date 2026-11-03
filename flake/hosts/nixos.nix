{ inputs, ... }:
let
  inherit (inputs)
    nixpkgs
    nix-ld
    vscode-server
    comfyui-nix
    home-manager
    sops-nix
    llm-agents
    minifluxng
    hermes-agent
    helium-flake
    ;
  inherit (import ../overlays.nix { inherit inputs; }) edge-overlay local-packages;
in
{
  flake.nixosConfigurations = {
    home-nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-ld.nixosModules.nix-ld
        vscode-server.nixosModules.default

        {
          nixpkgs.overlays = [
            llm-agents.overlays.shared-nixpkgs
            edge-overlay
            local-packages
          ];
        }
        hermes-agent.nixosModules.default
        ../../hosts/home-nixos/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.zhb = ../../hosts/home-nixos/user.nix;

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
        nix-ld.nixosModules.nix-ld
        comfyui-nix.nixosModules.default
        ../../hosts/zhb-nixos/configuration.nix
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # Keep the no-test policy local to ComfyUI's package set;
            # the upstream flake does not use the host's Python overlay.
            # Also cover Python-based build tools in this private nixpkgs
            # instance, not just the Python 3.12 runtime environment.
            noPythonTests =
              _final: prev:
              let
                withoutTests =
                  builder:
                  lib.mirrorFunctionArgs builder (
                    args:
                    (builder args).overrideAttrs {
                      doCheck = false;
                      doInstallCheck = false;
                    }
                  )
                  // {
                    override = args: withoutTests (builder.override args);
                  };
              in
              {
                buildPythonPackage = withoutTests prev.buildPythonPackage;
                buildPythonApplication = withoutTests prev.buildPythonApplication;
              };
            comfyPkgs = import nixpkgs {
              system = pkgs.stdenv.hostPlatform.system;
              overlays = [
                (_final: prev: {
                  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ noPythonTests ];

                })
              ];
              config = {
                allowUnfree = true;
                allowBrokenPredicate = pkg: (pkg.pname or "") == "open-clip-torch";
              };
            };
            versions = import "${comfyui-nix}/nix/versions.nix";
            gpuSupport = config.services.comfyui.gpuSupport;
            upstreamOverrides = import "${comfyui-nix}/nix/python-overrides.nix" {
              pkgs = comfyPkgs;
              inherit versions gpuSupport;
            };
            comfyPackages = import "${comfyui-nix}/nix/packages.nix" {
              pkgs = comfyPkgs;
              inherit lib versions gpuSupport;
              pythonOverrides = lib.composeManyExtensions [
                upstreamOverrides
                noPythonTests
                (final: prev: {
                  # iopath imports Protocol from typing_extensions, but
                  # the pinned nixpkgs package omits this runtime dependency.
                  iopath = prev.iopath.overridePythonAttrs (old: {
                    propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ final.typing-extensions ];
                  });
                })
              ];
            };
          in
          {
            services.comfyui.package = comfyPackages.default;
          }
        )
        {
          nixpkgs.overlays = [
            llm-agents.overlays.shared-nixpkgs
            helium-flake.overlays.default
            edge-overlay
            local-packages
          ];
        }
        # home-manager.nixosModules.home-manager
        # {
        #   home-manager.useGlobalPkgs = true;
        #   home-manager.useUserPackages = true;
        #   home-manager.users.zhb = ../../hosts/home-nixos/user.nix;
        #
        #   # Optionally, use home-manager.extraSpecialArgs to pass
        #   # arguments to home.nix
        # }
        sops-nix.nixosModules.sops
      ];
    };
  };

}
