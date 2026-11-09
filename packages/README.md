# Local packages

## new-api

`new-api.nix` packages the upstream `v1.0.0-rc.49` Release binary (including the
embedded Web UI), with pinned SHA-256 hashes. It is available as `pkgs.new-api`
in the local overlay and as `.#new-api` on supported flake package systems.
This is a **pre-release**, not a stable release. It does not require a local
Go/Bun build or Docker. Supported platforms are `x86_64-linux`, `aarch64-linux`,
and `aarch64-darwin`. The upstream macOS binary requires **macOS 26 or newer**
and is not an Intel/universal binary. Linux binaries are patched to use Nix's
glibc rather than host libraries.

Run these commands from the repository root:

```sh
just build-package new-api
./result/bin/new-api --version
./result/bin/new-api --help
```

For a manual run, build first, then use a writable working directory for the
SQLite database and logs. Keep the result path absolute when changing directory:

```sh
binary="$(realpath result)/bin/new-api"
mkdir -p "$HOME/.local/share/new-api"
cd "$HOME/.local/share/new-api"
"$binary" --port 3000 --log-dir ./logs
```

Open `http://localhost:3000` and complete the initial administrator setup.
**Upstream binds all network interfaces**: block external access with a firewall
until setup is complete, and use an authenticated HTTPS reverse proxy for any
public deployment. This package does not install or enable a service, change
firewall rules, or activate a host configuration.

Upstream supports `SQLITE_PATH`, `SQL_DSN` (MySQL/PostgreSQL),
`REDIS_CONN_STRING`, `SESSION_SECRET` and `CRYPTO_SECRET`. For a persistent
service, keep secrets in sops-nix/runtime environment files, not Nix expressions
or the Nix store. The wrapper supplies Nix's CA bundle unless `SSL_CERT_FILE`
is already set. License and attribution files are installed under
`share/doc/new-api`; upstream is AGPLv3 with additional attribution terms in
`NOTICE`.

The package's install check tests `--version`, `--help`, `/api/status`, and the
embedded HTML/JavaScript inside the Nix build sandbox. It starts with an existing
DELETE-journal SQLite fixture and verifies WAL activation and preserved data,
using both a plain `SQLITE_PATH` and the explicit home-nixos DSN. It does not
configure API providers or touch a host database. The rc.49 package build and
both WAL smoke cases passed on `x86_64-linux`; the final explicit DSN includes
`_txlock=immediate`. The full home-nixos system configuration also built
successfully without activation. ARM64 Linux and macOS runtime behavior must be
verified on those platforms.

To update, select a release, review its license and platform requirements,
update `version` and all three binary hashes from the release checksum files,
update the tagged source archive hash, then rebuild and run the install checks.

### home-nixos service and SQLite WAL

The system service uses the existing `zhb:zhb` account and database at
`/home/zhb/scripts/services/new-api/data/one-api.db`. Its `SQLITE_PATH` explicitly
sets `?_pragma=busy_timeout(30000)&_pragma=journal_mode(WAL)&_txlock=immediate`;
these are the
`glebarez/go-sqlite` driver's parameters. `_busy_timeout=30000` is not equivalent.
WAL allows readers alongside a writer; `BEGIN IMMEDIATE` takes the writer lock
at transaction start to avoid stale read-to-write upgrades. These reduce lock
contention but do not guarantee that every transaction or write will succeed. The existing service sandbox permits the
adjacent `-wal` and `-shm` files. Do not delete them while the service is running.

Before activating an upgrade, build first, then stop the service and make a
consistent backup. Run the following from the repository root, in order; stop
if any command fails. The backup contains credentials and is kept outside Git
with mode 0600. The Python backup API includes committed WAL data if present.

```sh
just build-package new-api
just build-package nixosConfigurations.home-nixos.config.system.build.toplevel --no-link
sudo systemctl stop new-api.service
test "$(systemctl is-active new-api.service)" = inactive
python3 - <<'PY'
import datetime
import os
from pathlib import Path
import sqlite3
import subprocess

state = subprocess.run(['systemctl', 'is-active', 'new-api.service'], capture_output=True, text=True)
assert state.stdout.strip() == 'inactive', 'Stop new-api.service before backing up'
os.umask(0o077)
root = Path('/home/zhb/scripts/services/new-api')
backups = root / 'backups'
backups.mkdir(mode=0o700, exist_ok=True)
backup = backups / ('one-api-before-rc49-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f') + '.db')
# Refuse to overwrite another backup.
fd = os.open(backup, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
os.close(fd)
try:
    with sqlite3.connect(f'file:{root}/data/one-api.db?mode=ro', uri=True) as source:
        with sqlite3.connect(backup) as target:
            source.backup(target)
            assert target.execute('PRAGMA quick_check').fetchall() == [('ok',)]
except BaseException:
    backup.unlink()
    raise
print('Verified backup:', backup)
PY
sudo just build-nixos home-nixos
systemctl is-active new-api.service
curl --fail --silent http://127.0.0.1:8056/api/status | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["success"] and d["data"]["version"] == "v1.0.0-rc.49"; print(d["data"]["version"])'
python3 - <<'PY'
import sqlite3
with sqlite3.connect('file:/home/zhb/scripts/services/new-api/data/one-api.db?mode=ro', uri=True) as db:
    mode = db.execute('PRAGMA journal_mode').fetchone()[0]
    assert mode == 'wal', mode
    print('journal_mode:', mode)
PY
```

If backup or activation fails, investigate before continuing; the service may
remain stopped. Before activation starts, the old service can be restarted with
`sudo systemctl start new-api.service`. After the new binary has run, do not
assume a Nix generation rollback also rolls back database migrations. Restoring
a backup requires stopping the service and handling the main database and its
WAL sidecars together; it also discards writes made since that backup. Do not
restore an old database beneath a running process.

## AOCI-CODE

`aoci-code.nix` packages upstream **0.1.0-rc21** release binaries for x86_64/ARM64
Linux and ARM64 macOS, with a separate pinned SHA-256 for each archive.
It is available as `pkgs.aoci-code` in the local overlay and as `.#aoci-code`
on the flake's exported package systems. The executable is `aoci`; Git is
provided on its runtime PATH. Adding the package does not install it on any host.

Upstream uses **FSL-1.1-MIT**, a non-free/source-available license with a future
MIT grant, not a current MIT license. After reviewing its terms, build without
activating a system configuration:

```sh
just build-aoci-code
./result/bin/aoci --version
./result/bin/aoci --help
```

The recipe permits unfree software only for that invocation; it does not change
any host's `allowUnfree` policy. For declarative installation, allow `aoci-code`
through the host's `nixpkgs.config.allowUnfreePredicate` if necessary.

These are upstream binaries, not source builds: this release requires Go 1.26.9,
while the locked nixpkgs provides Go 1.26.8. Archive hashes come from the tagged
release's `SHA256SUMS`. The local build checks the archive hash, installed version
and help output (upstream's basic verification level); Sigstore signatures and
provenance attestations have not been independently verified. To update, select
a release, update `version` and all three archive hashes, review its license and
archive contents, then rebuild and smoke-test on available platforms.

Validated on `aarch64-darwin`: package build, archive hash, installed `--version`
and `--help`. Both Linux package outputs were evaluated, but not built locally.

## Rust CLI tools

The local overlay provides pinned crates.io builds (including locked Cargo
dependencies), equivalent to installing the corresponding crate with Cargo:

| Package | Version | Executable |
| --- | --- | --- |
| `knots` | 1.18.0 | `knots` |
| `cccc-cli` | 1.8.3 | `cccc` |

Build without installing or activating a host configuration (Linux or macOS):

```sh
nix build .#knots
./result/bin/knots --version
nix build .#cccc-cli
./result/bin/cccc --version
```

Hosts that import this overlay can add `pkgs.knots` and `pkgs.cccc-cli` to
their package lists. Adding these definitions does not install them on any host.

Both packages were built and tested on `aarch64-darwin`, including installed
binary version checks. `cccc-cli` was also built and tested on `x86_64-linux`:
all 109 tests, the installed version check, and a Ruby analysis smoke test pass.
Its `ruby-prism-sys` dependency needs `rustPlatform.bindgenHook`; on Linux,
target-specific bindgen arguments must also include the libc headers because
the dependency's vendored build overrides the hook's generic arguments.
`knots` passes 354 tests and skips only `tests::rust_fixture_crate_file_ce`,
whose fixture is absent from the published crate; its Linux output was
only evaluated, not built locally.
