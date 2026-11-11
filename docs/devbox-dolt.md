# devbox: authenticated Beads Dolt SQL Server

`hosts/devbox/user-systemd.nix` declares `dolt.service` as a Home Manager
user service; `hosts/devbox/user.nix` installs Dolt and imports Home Manager's
sops-nix module.

- TCP: **0.0.0.0:3307** (all IPv4 interfaces, not IPv6).
- Unix socket: `$XDG_RUNTIME_DIR/dolt.sock`.
- Persistent databases: `~/scripts/services/dolt/<database>/`.
- Privilege state: `~/scripts/services/dolt/.doltcfg/privileges.db`.
- Home Manager tmpfiles creates the data root with mode `0700`; umask is `0077`.
- This remains a user service; the devbox user currently has linger enabled.

## SOPS root password and safe startup

The random root password is encrypted in `secrets/devbox-dolt.yaml` under
`dolt-root-password`, to the dedicated devbox age recipient and the admin key.
The devbox private identity is `~/.config/sops/age/keys.txt` (mode 0600); it is
**not in Git or the Nix store**. Back it up securely before reinstalling the
host. `.sops.yaml` grants that identity access only to this dedicated secret.
Do not replace the identity without re-encrypting to its new recipient.

The user unit requires and follows **user** `sops-nix.service`, loads the
0400 decrypted secret via systemd `LoadCredential`, then runs
`scripts/dolt-prepare-root.py` in `ExecStartPre`. That helper performs **offline**
SQL under the existing data root, creates/updates `root@%` plus existing root
host variants, and grants root privileges. Missing, empty or short secrets and
SQL errors prevent startup. SQL containing passwords goes through a subprocess
stdin, not argv, a generated store file, persistent SQL file or journal.

Dolt's `DOLT_ROOT_PASSWORD` alone is insufficient: it only works on first
initialization and is ignored when `privileges.db` already exists. Offline
provisioning therefore runs on **every service start**, supporting existing
passwordless state and password rotation while preserving databases and other
users. The main server uses `--skip-root-user-initialization`, so it cannot
silently create a passwordless default root. Other pre-existing accounts retain
their permissions/passwords: audit them before enabling remote access.

Root can authenticate remotely (`root@%`) as requested. This is not a
least-privilege application account: create restricted users for applications.
The data-directory owner still has offline superuser access by Dolt design.

**Networking:** no host/upstream firewall rules are opened by this configuration.
Passwords do not encrypt SQL traffic; this configuration does not enable TLS.
Use an authenticated VPN/SSH tunnel or configure Dolt TLS before permitting
untrusted-network access. Restrict allowed client IPs rather than exposing
3307 generally to the Internet.

## Rotate, activate and inspect

Edit the encrypted secret, without putting passwords in shell arguments:

```sh
sops secrets/devbox-dolt.yaml
just build-devbox
systemctl status home-manager-zhanghaibin.zhb.service --no-pager
systemctl --user restart dolt.service
systemctl --user status sops-nix.service dolt.service --no-pager
journalctl --user -u dolt.service -n 50 --no-pager
# --user root prompts for the password; do not pass it via --password on argv.
dolt --host 127.0.0.1 --port 3307 --user root --no-tls --use-db mysql sql -q "SHOW DATABASES"
```

Before changing credentials on existing data, stop the service and make a
consistent backup of the entire data root, including `.doltcfg`. Stop any
independently launched server using that same data root. The new password is
applied at service start; restarting only sops-nix does not rotate an already
running server. On the first run, activation decrypts SOPS before starting Dolt.
For subsequent secret edits, explicitly restart Dolt after successful Home
Manager activation, as above. Do not bypass the startup helper or use a bare
`dolt sql-server` with an old passwordless privilege file.

## Use with Beads

For a **new, uninitialized** workspace, read the runtime secret into the current
process environment without displaying it, then initialize:

```sh
BEADS_DOLT_PASSWORD="$(< "$HOME/.config/sops-nix/secrets/dolt-root-password")" \
  bd init --server --external --server-host 127.0.0.1 --server-port 3307 \
  --server-user root --non-interactive
```

This example uses Bash; other shells can read the secret file equivalently.
Prefer a least-privilege account for ongoing application use. Subsequent Beads
commands also need the password through their supported environment/credentials
mechanism; never copy it into Git. Existing Beads databases are not migrated or
reinitialized automatically. Distinct workspaces need distinct database names.

## Validate without activation

```sh
nix eval --accept-flake-config --impure --json --file scripts/tests/test-dolt-service.nix
# Pass the built binary and absolute helper path:
python3 -B scripts/tests/test-dolt-auth.py /path/to/dolt "$PWD/scripts/dolt-prepare-root.py"
```

The runtime regression uses temporary directories and loopback-only random
ports: it rejects missing/weak passwords, verifies correct/incorrect/empty
password behavior, rotates credentials, and checks database data survives.
No live host database or external listener is touched.

Validated on x86_64-linux with pinned Dolt 2.5.0: the full devbox configuration
built, all 11 HM/SOPS wiring checks passed, generated user units verified,
authentication/rotation/data-preservation checks passed, and a separately
created legacy passwordless `root@localhost` was secured before restart.
These checks did not activate or open the external listener.
