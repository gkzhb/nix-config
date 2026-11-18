{ config, lib, ... }:

let
  user = "zhanghaibin.zhb";
  secret = config.sops.secrets.uv-config;
in
{
  # Reuse the host's existing age identity, but keep uv separate from Dolt.
  sops.secrets.uv-config = {
    sopsFile = ../../../secrets/devbox-uv.yaml;
    format = "yaml";
    key = "uv-config";
    owner = user;
    group = user;
    mode = "0400";
  };

  home-manager.users.${user} =
    { config, lib, ... }:
    let
      directory = "${config.xdg.configHome}/uv";
    in
    {
      # Never link the whole mutable checkout directory or copy secret contents
      # into a Home Manager derivation. Only the runtime path enters the store.
      dotfiles.configLinks.uv = lib.mkForce null;
      xdg.configFile."uv/uv.toml".source = config.lib.file.mkOutOfStoreSymlink secret.path;
      home.activation.checkUvConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [[ -L ${lib.escapeShellArg directory} ]]; then
          echo "uv config directory is a symlink; follow docs/devbox-uv.md before activating." >&2
          exit 1
        fi
        if [[ ! -r ${lib.escapeShellArg secret.path} ]]; then
          echo "Decrypted uv config is unavailable; check sops-install-secrets.service." >&2
          exit 1
        fi
      '';
    };

  # Do not install a dangling config when decryption fails on first activation.
  systemd.services."home-manager-${user}" = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
