# devbox: system Dolt SQL Server with authenticated TLS

`hosts/devbox/modules/dolt.nix` defines `dolt.service` as a **System Manager
system service**, running as the existing `zhanghaibin.zhb` account (not root).
Home Manager no longer owns Dolt or its secret service. Global CLI packages
include Dolt, sops, age, mkcert and openssl.

- TCP: **0.0.0.0:3307**, all IPv4 interfaces, **TLS required**.
- Client endpoint: **dolt.byte.gkzhb.top:3307**.
- Unix socket: **/run/dolt/dolt.sock**, under a 0700 user-owned runtime directory.
- Persistent databases: `~/scripts/services/dolt/<database>/` (unchanged).
- Privilege state: `~/scripts/services/dolt/.doltcfg/privileges.db` (unchanged).
- `dolt-data-directory.service` is the sole owner of data-root preparation.
  It waits for the data mount and runs as the Dolt user, creating the directory
  0700 before Dolt enters WorkingDirectory, including first activation.
  Privileged system tmpfiles must not manage this HOME path.
- The service starts with `system-manager.target`; user linger is no longer
  required for Dolt.

## Symlinked HOME and tmpfiles safety

On devbox, `/home/zhanghaibin.zhb` resolves through `/data00` (owned by `tiger`)
into `/data00/home` (owned by root). systemd-tmpfiles rejects that ownership
transition during privileged path canonicalization. A redundant data-directory
rule previously made System Manager activation return an error even when Home
Manager and Dolt had started successfully.

Keep directory creation in the ordered user-run preparation service, not in
`systemd.tmpfiles.rules`. Do not chown `/data00`, relax parent permissions, or
change the database path to work around this check. The user-run service cannot
repair root-owned data: inspect existing ownership and backups rather than
adding privileged recursive chown. Activation is not transactional; inspect
Home Manager and Dolt separately after any error.

## Root password and system SOPS

`secrets/devbox-dolt.yaml` contains **only** the encrypted `dolt-root-password`,
with the original password preserved. System sops-nix decrypts it as a root-only
0400 runtime secret at `/run/secrets/dolt-root-password`. The age identity
remains `~/.config/sops/age/keys.txt` (0600), outside Git/store; the system
activation process reads it. Securely back it up before reinstalling.

The system unit waits for `sops-install-secrets.service`, loads the secret with
`LoadCredential`, then runs `scripts/dolt-prepare-root.py` in `ExecStartPre`.
That helper provisions root credentials through **offline SQL before opening
TCP**, including existing root host variants. Missing/weak passwords and SQL
failures prevent startup. Passwords are not placed in argv, store files,
persistent SQL files or the journal. Root changes apply on each service start;
sops-nix requests a system service restart on root secret changes.

The main process uses `--skip-root-user-initialization`. The data-directory
owner retains offline superuser access by Dolt design. Other pre-existing SQL
accounts are not changed: audit them before allowing remote access, and use
least-privilege application accounts rather than root.

## Original Nginx TLS files

Systemd reads the original, root-protected Nginx certificate sources:

- `/etc/letsencrypt/live/byte.gkzhb.top/fullchain.pem`
- `/etc/letsencrypt/live/byte.gkzhb.top/privkey.pem`

The system manager passes private runtime credential snapshots to the unprivileged
Dolt process. **No source permissions are relaxed, no TLS key/cert is copied
into sops or the Nix store.** Invalid/missing credentials prevent startup.
`listener.require_secure_transport: true` rejects plaintext TCP. The local
Unix socket stays on this machine and is not TLS.

The Let's Encrypt certificate covers `byte.gkzhb.top` and `*.byte.gkzhb.top`.
Clients with current public roots do not need a private CA import. Connect via
**dolt.byte.gkzhb.top**, not localhost, `127.0.0.1` or bare host IP, which are not
in its SANs. Do not use `--no-tls` or skip certificate verification. No system
or browser trust-store changes are made. mkcert is available as a tool but is
not the certificate used by Dolt.

**Renewal:** `certbot-renew.timer` checks the existing certificate monthly.
After successful renewal, its deploy hook restarts an active `dolt.service`
to refresh the systemd credential snapshots, with **no re-encryption or Nix
rebuild required**. Failed/skipped renewals and inactive Dolt are left alone.
See [devbox Certbot migration](devbox-certbot.md) for cron removal and verification.

Dolt and systemd credentials do not live-reload files. If renewing manually
outside the managed service, run `sudo systemctl restart dolt.service` after
successful renewal. Do not stop database service in a failed-renewal hook. Reusing
Nginx's wildcard key means the Dolt process user can access its runtime copy;
a dedicated publicly issued certificate reduces that cross-service exposure.

TLS encrypts TCP SQL queries/results, but does not justify general Internet
exposure of root. No firewall rules are opened here. Restrict source IPs/VPN
peers and keep root/admin credentials separate from application accounts.

## Migrate and activate

The system service is ordered after successful Home Manager activation, which
removes the legacy user unit. Before first activation explicitly stop/disable
the old service and consistently back up the entire data root if it exists:

```sh
systemctl --user disable --now dolt.service
# Back up ~/scripts/services/dolt and .doltcfg while all servers using it are stopped.
just build-devbox
systemctl status home-manager-zhanghaibin.zhb.service sops-install-secrets.service dolt.service --no-pager
journalctl -u dolt.service -n 50 --no-pager
# Prompts for root password, normal public CA + hostname validation:
dolt --host dolt.byte.gkzhb.top --port 3307 --user root --use-db mysql sql -q "SHOW DATABASES"
```

Do not judge success solely by System Manager exit status. Verify Home Manager
succeeded and no legacy `systemctl --user` Dolt process is still running. If
Home Manager activation fails, the system Dolt dependency fails closed rather
than running concurrently against the same data root.

Rotate only the SOPS root password with `sops secrets/devbox-dolt.yaml`, then
reactivate and check system service status. Do not manually delete the privilege
DB or bypass offline preparation.

## Use with Beads

For a new workspace, provide the password via Beads' supported environment or
credential mechanism and enable TLS. Root runtime secrets are no longer
user-readable at the former Home Manager path. Read only the specific password
with sudo into the current process without printing it, or use a separately
provisioned least-privilege account. Bash example (disable shell tracing):

```sh
BEADS_DOLT_SERVER_TLS=1 \
BEADS_DOLT_PASSWORD="$(sudo cat /run/secrets/dolt-root-password)" \
  bd init --server --external --server-host dolt.byte.gkzhb.top --server-port 3307 \
  --server-tls --server-user root --non-interactive
```

`--server-tls` during initialization is not persisted by Beads; keep TLS enabled
for later invocations. Existing Beads databases are not automatically migrated
or reinitialized. Distinct workspaces need distinct DB names.

## Validate without activation

```sh
nix eval --accept-flake-config --impure --json --file scripts/tests/test-dolt-service.nix
just build-package systemConfigs.devbox.config.build.toplevel --no-link
python3 -B scripts/tests/test-dolt-auth.py /path/to/dolt "$PWD/scripts/dolt-prepare-root.py"
```

`test-dolt-tls.py` takes `<dolt> <generated YAML> <temporary credential dir>
<CA-or-dash> <hostname>` (`-` for public roots). It creates temporary state,
rewrites only listener/data/socket locations for the test, and uses an actual
MySQL TLS client to verify encrypted queries/results, plaintext/empty/wrong
password denial, CA validation and wrong-hostname rejection. Never use a live
production data root for regression tests.

Validated on x86_64-linux: full devbox build, 15 configuration assertions,
system-level original cert/key credential access for the ordinary service user,
and TLSv1.3 encrypted SQL/results with plaintext/bad-password rejection and
CA/hostname verification. These checks did not activate the production service.
