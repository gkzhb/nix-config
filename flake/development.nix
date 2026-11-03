{
  inputs,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ../treefmt.nix;
      treefmt-stage = pkgs.writeShellApplication {
        name = "treefmt-stage";
        runtimeInputs = [
          pkgs.git
          treefmtEval.config.build.wrapper
        ];
        text = ''
          treefmt "$@"
          git add -- "$@"
        '';
      };
      gitHooks = inputs.git-hooks.lib.${system}.run {
        src = ../.;
        hooks.treefmt-stage = {
          enable = true;
          name = "treefmt-stage";
          entry = "${treefmt-stage}/bin/treefmt-stage";
          files = "\\.nix$";
          pass_filenames = true;
          require_serial = true;
        };
      };
    in
    {
      formatter = treefmtEval.config.build.wrapper;
      checks.formatting = treefmtEval.config.build.check self;
      devShells = {
        default = pkgs.mkShell {
          packages = gitHooks.enabledPackages;
          shellHook = gitHooks.shellHook;
        };
      };
    };
}
