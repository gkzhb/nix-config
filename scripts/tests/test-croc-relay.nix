# Evaluate the host service and secret wiring without activation.
# nix eval --accept-flake-config --impure --json --file scripts/tests/test-croc-relay.nix
let
  flake = builtins.getFlake ("path:" + toString ../..);
  inherit (flake.inputs.nixpkgs) lib;
  cfg = flake.systemConfigs.gkzhb-vps.config;
  service = cfg.systemd.services.croc-relay;
  secret = cfg.sops.secrets.croc-relay-password;
  template = cfg.sops.templates."croc-relay.env";
  checks = {
    managedBySystemManager = service.wantedBy == [ "system-manager.target" ];
    waitsForNetworkAndSecrets =
      builtins.elem "network-online.target" service.wants
      && builtins.elem "network-online.target" service.after
      && builtins.elem "sops-install-secrets.service" service.requires
      && builtins.elem "sops-install-secrets.service" service.after;
    relayPorts = lib.hasSuffix "/bin/croc relay --ports 9009,9010" service.serviceConfig.ExecStart;
    runtimeEnvironment = service.serviceConfig.EnvironmentFile == template.path;
    dynamicUser = service.serviceConfig.DynamicUser;
    restarts = service.serviceConfig.Restart == "always";
    encryptedSecret =
      builtins.baseNameOf secret.sopsFile == "gkzhb-vps-croc-relay.yaml"
      &&
        builtins.hashFile "sha256" secret.sopsFile
        == builtins.hashFile "sha256" ../../secrets/gkzhb-vps-croc-relay.yaml
      && secret.format == "yaml"
      && secret.mode == "0400";
    privateEnvironment =
      template.mode == "0400"
      && template.restartUnits == [ "croc-relay.service" ]
      && template.content == "CROC_PASS=${cfg.sops.placeholder.croc-relay-password}\n";
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
assert lib.assertMsg (
  failures == [ ]
) "Failed croc relay checks: ${lib.concatStringsSep ", " failures}";
{
  inherit checks;
  unit = cfg.systemd.units."croc-relay.service".text;
}
