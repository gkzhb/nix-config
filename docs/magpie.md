# Magpie CLI gateway on devbox

Magpie is installed declaratively from the official `github:yetone/magpie-releases` flake, pinned in `flake.lock` (initially CLI `0.1.4936`, release repository revision `24025d504160a9b7387cff0e763ca6f934680e8c`). Only the terminal-only `magpie-cli` package is installed; its executable is `magpie`. No GTK/WebKit desktop runtime or curl installer is needed.

## Service

`hosts/devbox/user-systemd.nix` installs the CLI in Home Manager and defines `magpie.service` for `zhanghaibin.zhb`:

- Foreground command: `magpie serve`.
- Gateway: `http://127.0.0.1:3425` (OpenAI API base: `/v1`). No LAN/public binding or web admin UI is enabled.
- Enabled for the user's `default.target`, with restart on failure.
- Existing user XDG directories are retained; Magpie writes its own mutable settings under `~/.config/magpie`. No provider keys or account files are placed in the Nix store.
- New files are private (`UMask=0077`), telemetry is disabled (`DO_NOT_TRACK=1`), and automatic discovery of other agents' sign-ins is disabled (`MAGPIE_NO_ACCOUNTS=1`). Explicitly add the providers/accounts you want to use.
- Stop drains requests for up to 30 seconds; systemd allows 45 seconds. The pinned CLI logs its drain handler and then exits via SIGTERM (Python reports `-15`); systemd treats SIGTERM as a clean stop for this `Type=simple` unit, so no extra `SuccessExitStatus` is needed.

The service alone does not configure a provider or change New API/Pi/other agents. Do not use `magpie claude`, `magpie codex`, profiles, or agent setup commands unless you intend to rewrite those agents' settings.

## Build and validate (no activation)

```sh
just build-package magpie-cli --no-link
just test-magpie-service
# Optional isolated runtime smoke test (no user credentials or activation):
nix build .#magpie-cli --accept-flake-config --out-link /tmp/magpie-smoke-package
python3 scripts/tests/test-magpie-cli.py /tmp/magpie-smoke-package/bin/magpie
```

After checking all pending repository changes, explicitly activate when ready:

```sh
just build-devbox
just check-home-manager zhanghaibin.zhb
systemctl --user status magpie.service
journalctl --user -u magpie.service -n 50 --no-pager
magpie healthcheck
```

**`just build-devbox` switches the entire System Manager/Home Manager configuration**, not only Magpie, and can restart unrelated changed units. This task does not run it automatically.

User units start with the user manager. Starting at boot without a login also requires user lingering. On this devbox, `loginctl show-user zhanghaibin.zhb -p Linger` reports `Linger=yes`; the new enabled unit can start with that existing user manager after activation. This configuration does not modify lingering.

## Configure providers and accounts

Use `magpie tui` or the CLI as this same user to manage providers in the shared XDG state. Use `magpie provider --help` and `magpie accounts --help` for the pinned release's supported input methods. Do not put real keys in this repository, Nix expressions, shell history, or command transcripts; use interactive entry or an officially supported private input method. For declarative secrets, use the repository's sops-nix workflow and runtime secret paths, never a literal Nix value.

A gateway with no provider configured can be healthy but cannot answer model requests. After adding one, validate a small request with its actual `provider/model` ID. Inference and provider login were not exercised by the package/unit tests.

For remote access, keep the service on loopback and use an SSH tunnel first. Before enabling a LAN listener or reverse proxy, configure gateway keys and TLS/access controls; loopback placeholder auth must not be assumed safe for remote clients.

## Updates

```sh
just update-magpie
just build-package magpie-cli --no-link
just test-magpie-service
# Explicitly activate only after reviewing the change:
just build-devbox
```

This updates only `magpie-releases`. The executable is immutable in the Nix store; Magpie self-update is not the installation path.

## References

- https://github.com/yetone/magpie-releases
- https://github.com/yetone/magpie
- https://usemagpie.ai/docs/docker (server mode, listen address, XDG state, drain and healthcheck contracts)
