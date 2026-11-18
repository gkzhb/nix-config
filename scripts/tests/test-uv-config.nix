# Evaluate actual devbox SOPS/Home Manager uv wiring without reading plaintext.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-uv-config.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.devbox.config;
  user = "zhanghaibin.zhb";
  home = cfg.home-manager.users.${user};
  secret = cfg.sops.secrets.uv-config;
  file = home.xdg.configFile."uv/uv.toml";
  unit = cfg.systemd.services."home-manager-${user}";
  checks = {
    dedicatedEncryptedFile = lib.hasSuffix "/secrets/devbox-uv.yaml" (toString secret.sopsFile);
    fullConfig = secret.format == "yaml" && secret.key == "uv-config";
    privateUserAccess = secret.owner == user && secret.group == user && secret.mode == "0400";
    runtimePath = secret.path == "/run/secrets/uv-config";
    noTemplates = cfg.sops.templates == { };
    noWholeDirectory = home.dotfiles.configLinks.uv == null && !(home.xdg.configFile ? uv);
    onlyRuntimeLink =
      lib.hasInfix "ln -s ${secret.path} $out" file.source.buildCommand && !file.force && !file.recursive;
    sourceHasNoPlaintext = lib.hasInfix "/run/secrets/uv-config" file.source.buildCommand;
    preservesDiscovery = !(home.home.sessionVariables ? UV_CONFIG_FILE);
    waitsForDecryption =
      builtins.elem "sops-install-secrets.service" unit.after
      && builtins.elem "sops-install-secrets.service" unit.requires;
    safeMigration =
      home.home.activation.checkUvConfig.before == [ "checkLinkTargets" ]
      && lib.hasInfix "-L" home.home.activation.checkUvConfig.data;
    decryptionPreflight = lib.hasInfix "-r /run/secrets/uv-config" home.home.activation.checkUvConfig.data;
    doltSecretUnchanged =
      cfg.sops.secrets.dolt-root-password.owner == "root"
      && cfg.sops.secrets.dolt-root-password.mode == "0400";
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed uv config checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  runtimeLinkDrv = file.source.drvPath;
  sopsManifestDrv = cfg.system.build.sops-nix-manifest.drvPath;
}
