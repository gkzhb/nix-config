# devbox: encrypted uv configuration

## Storage and ownership

- `secrets/devbox-uv.yaml` stores the **entire** current `uv.toml` as the encrypted `uv-config` string. Only admin and devbox are recipients.
- `hosts/devbox/modules/uv.nix` declares a separate system SOPS secret, reusing the existing devbox age identity without changing Dolt secrets.
- At runtime sops-nix decrypts to `/run/secrets/uv-config`, owned by `zhanghaibin.zhb`, mode `0400`. Plaintext never enters a Nix derivation or template.
- Home Manager disables the whole-directory dotfiles mapping for devbox and links only `~/.config/uv/uv.toml` to the runtime secret. Other files under `~/.config/uv` remain local. No `UV_CONFIG_FILE` is set, preserving ordinary uv project/user configuration discovery.
- Home Manager requires and starts after `sops-install-secrets.service`; its preflight refuses a symlinked uv directory or unreadable secret rather than writing through the old checkout link or installing a dangling configuration.

The shared dotfiles repository **keeps its original tracked `uv.toml`** for other hosts. Only devbox disables that directory mapping and uses its private encrypted configuration instead. Do not replace the shared baseline with the devbox secret or delete it during migration. Other hosts keep their existing mapping and do not receive the devbox internal index or a new SOPS recipient.

## First activation on this devbox

For a devbox that still uses the old mapping, `~/.config/uv` is a whole-directory Home Manager symlink. Replace **only that symlink**, not its target, before activating. The implementation session preserved the devbox-specific configuration in mode-0400 backups under `~/.local/state/uv-config-migration/`; the active devbox is now migrated. The shared checkout retains its original configuration for other hosts. Never copy the devbox private backup into that tracked file or print its contents.

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

Expected resolved target is under `/run/secrets.d/<generation>/uv-config` (via `/run/secrets/uv-config`), mode `400`, owned by the devbox user. Once verified, privately held migration backups can be removed when no longer needed. Do not remove the new `~/.config/uv/uv.toml` link or the tracked `dotfiles/.config/uv/uv.toml` used by other hosts.

## Edit and validate

```sh
sops secrets/devbox-uv.yaml
just test-uv-config
just build-devbox
```

Edit the multiline `uv-config` value in the SOPS editor; never copy decrypted content into Nix `writeText`, `home.file.text`, environment variables or a tracked dotfile. Runtime config is intentionally read-only.

SOPS protects repository contents, not all uses of the URL: old Git history, old Nix source snapshots, uv lock/export files, caches and verbose logs can retain addresses. This change does not rewrite history, erase old store objects or rotate credentials. If an actual credential was exposed, rotate it; avoid putting credentials into URLs.
