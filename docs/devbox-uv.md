# devbox: encrypted uv configuration

## Storage and ownership

- `secrets/devbox-uv.yaml` stores the **entire** current `uv.toml` as the encrypted `uv-config` string. Only admin and devbox are recipients.
- `hosts/devbox/modules/uv.nix` declares a separate system SOPS secret, reusing the existing devbox age identity without changing Dolt secrets.
- At runtime sops-nix decrypts to `/run/secrets/uv-config`, owned by `zhanghaibin.zhb`, mode `0400`. Plaintext never enters a Nix derivation or template.
- Home Manager disables the whole-directory dotfiles mapping for devbox and links only `~/.config/uv/uv.toml` to the runtime secret. Other files under `~/.config/uv` remain local. No `UV_CONFIG_FILE` is set, preserving ordinary uv project/user configuration discovery.
- Home Manager requires and starts after `sops-install-secrets.service`; its preflight refuses a symlinked uv directory or unreadable secret rather than writing through the old checkout link or installing a dangling configuration.

The shared dotfiles repository no longer tracks plaintext `uv.toml`; `.config/uv/.gitignore` excludes host-local copies. Other hosts **do not** receive this internal index or a new recipient. Before pulling the removal on another host that uses it, preserve its local configuration privately or implement that host's own SOPS secret. With no user index configuration, uv normally falls back to PyPI; project settings can still override it.

## First activation on this devbox

The existing `~/.config/uv` is a whole-directory Home Manager symlink. Replace **only that symlink**, not its target, before activating. The implementation session kept an exact mode-0400 backup under `~/.local/state/uv-config-migration/pre-sops-*/uv.toml` and an ignored checkout symlink to it so uv keeps its current configuration until migration. Do not commit that transitional symlink or print the backup content.

Run these commands in Bash/sh immediately before activation (not concurrently with uv jobs):

```sh
set -eu
old="$HOME/.config/uv"
mkdir -p "$HOME/.local/state/uv-config-migration"
backup_dir="$(mktemp -d "$HOME/.local/state/uv-config-migration/manual.XXXXXX")"
chmod 700 "$backup_dir"
cp -L "$old/uv.toml" "$backup_dir/uv.toml"
chmod 400 "$backup_dir/uv.toml"
case "$(readlink "$old")" in
  /nix/store/*-home-manager-files/.config/uv) ;;
  *) echo 'Not the expected old Home Manager directory symlink; stop and inspect.' >&2; exit 1 ;;
esac
unlink "$old"
mkdir -m 700 "$old"
# Preserve uv behavior until Home Manager replaces this equal-content link.
ln -s "$backup_dir/uv.toml" "$old/uv.toml"
printf 'Private migration backup: %s\n' "$backup_dir"
just build-devbox
```

Do not set `force = true` or delete unrelated local files to bypass a collision. A hand-edited configuration different from the encrypted secret needs review/re-encryption first; Home Manager should reject silently overwriting it. If activation fails, the private backup link remains usable unless Home Manager already replaced it. Check the link and secret before retrying; activation is not a transaction.

Verify without displaying the URL:

```sh
systemctl status sops-install-secrets.service home-manager-zhanghaibin.zhb.service --no-pager
test -d "$HOME/.config/uv" && test ! -L "$HOME/.config/uv"
test -r "$HOME/.config/uv/uv.toml"
realpath "$HOME/.config/uv/uv.toml"
stat -Lc '%a %U %G' /run/secrets/uv-config
uv --offline python find
```

Expected resolved target is under `/run/secrets.d/<generation>/uv-config` (via `/run/secrets/uv-config`), mode `400`, owned by the devbox user. Once verified, remove the ignored checkout `uv.toml` symlink and privately held migration backups you no longer need. Do not remove the new `~/.config/uv/uv.toml` link.

## Edit and validate

```sh
sops secrets/devbox-uv.yaml
just test-uv-config
just build-devbox
```

Edit the multiline `uv-config` value in the SOPS editor; never copy decrypted content into Nix `writeText`, `home.file.text`, environment variables or a tracked dotfile. Runtime config is intentionally read-only.

SOPS protects repository contents, not all uses of the URL: old Git history, old Nix source snapshots, uv lock/export files, caches and verbose logs can retain addresses. This change does not rewrite history, erase old store objects or rotate credentials. If an actual credential was exposed, rotate it; avoid putting credentials into URLs.
