# Non-activating provenance regression test. Run each section independently:
# nix eval --accept-flake-config --impure --json --expr \
#   'import ./scripts/tests/edge-packages.nix { flakeRef = toString ./.; section = "nixos"; }'
{
  flakeRef,
  section ? "nixos",
}:
let
  flake = builtins.getFlake flakeRef;
  lib = flake.inputs.nixpkgs.lib;
  targets = [
    "tuios"
    "pi-coding-agent"
    "deepseek-harness"
  ];
  checkHost =
    pkgs: installed: expectedNames:
    let
      expected = import flake.inputs.nixpkgs-edge {
        system = pkgs.stdenv.hostPlatform.system;
        inherit (pkgs) config;
      };
      selected = builtins.filter (pkg: builtins.elem (lib.getName pkg) targets) installed;
      names = builtins.sort builtins.lessThan (map lib.getName selected);
      packageInfo = lib.genAttrs expectedNames (name: {
        inherit (pkgs.edge.${name}) version drvPath;
      });
    in
    assert names == builtins.sort builtins.lessThan expectedNames;
    assert builtins.all (pkg: pkg.drvPath == expected.${lib.getName pkg}.drvPath) selected;
    # Ordinary packages must not be replaced by the edge package set.
    assert
      pkgs.git.drvPath
      == flake.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.git.drvPath;
    assert !(pkgs.edge ? edge);
    packageInfo;
  # Home Manager normalizes ExecStart to a list; system services use a string.
  command = value: if builtins.isList value then lib.concatStringsSep " " value else value;
  checkConfig =
    value: expectedNames: checkHost value.pkgs value.config.environment.systemPackages expectedNames;
  checkSystemManager =
    value: expectedNames:
    checkHost value.config.nixpkgs.pkgs value.config.environment.systemPackages expectedNames;
  homeNixos = flake.nixosConfigurations.home-nixos;
  devboxHome = flake.homeConfigurations."zhanghaibin.zhb";
  darwin = flake.darwinConfigurations.gkzhb-MBP;
in
if section == "nixos" then
  {
    home-nixos = checkConfig homeNixos targets;
    zhb-nixos = checkConfig flake.nixosConfigurations.zhb-nixos [
      "tuios"
      "pi-coding-agent"
    ];
    dshExec =
      let
        exec = command homeNixos.config.home-manager.users.zhb.systemd.user.services.dsh-web.Service.ExecStart;
      in
      assert lib.hasPrefix "${homeNixos.pkgs.edge.deepseek-harness}/bin/dsh " exec;
      exec;
  }
else if section == "system-manager" then
  {
    devbox = checkSystemManager flake.systemConfigs.devbox targets;
    mido = checkSystemManager flake.systemConfigs.mido targets;
    gkzhb-vps = checkSystemManager flake.systemConfigs.gkzhb-vps [ "tuios" ];
    midoDshExec =
      let
        value = flake.systemConfigs.mido;
        exec = value.config.systemd.services.dsh-web.serviceConfig.ExecStart;
      in
      assert lib.hasPrefix "${value.config.nixpkgs.pkgs.edge.deepseek-harness}/bin/dsh " exec;
      exec;
  }
else if section == "darwin" then
  {
    packages = checkConfig darwin [
      "tuios"
      "pi-coding-agent"
    ];
    tuiosPath =
      let
        path = darwin.config.launchd.user.agents.tuios-web.serviceConfig.EnvironmentVariables.PATH;
      in
      assert lib.hasPrefix "${darwin.pkgs.edge.tuios}/bin:" path;
      path;
  }
else if section == "home" then
  let
    exec = command devboxHome.config.systemd.user.services.dsh-web.Service.ExecStart;
  in
  assert lib.hasPrefix "${devboxHome.pkgs.edge.deepseek-harness}/bin/dsh " exec;
  {
    dshExec = exec;
  }
else
  throw "Unknown edge provenance test section: ${section}"
