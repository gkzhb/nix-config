# Local packages

## new-api

`new-api.nix` packages the upstream `v1.0.0-rc.47` Release binary (including the
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

The package's install check tests `--version`, `--help`, SQLite initialization,
`/api/status`, and the embedded HTML/JavaScript inside the Nix build sandbox,
without configuring API providers or touching a host database. Validated by a
full build and install check on `x86_64-linux`. ARM64 Linux and macOS package
outputs were evaluated and their release binaries/hashes inspected, but not
built or runtime-tested on those hosts.

To update, select a release, review its license and platform requirements,
update `version` and all three binary hashes from the release checksum files,
update the tagged source archive hash, then rebuild and run the install checks.

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
