# Devbox Botmux fonts

`hosts/devbox/user.nix` imports `hosts/devbox/botmux-fonts.nix` only for the
`devbox` Home Manager user. Other hosts and shared dotfiles do not get these
links.

The module declares five individual, non-forced files under
`~/.botmux/fonts/`:

- `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Bold.ttf`: `pkgs.jetbrains-mono`.
- `NotoSansMonoCJKsc-Regular.otf`, `NotoSansMonoCJKsc-Bold.otf`: static SC mono
  faces extracted from `pkgs.noto-fonts-cjk-sans.override { static = true; }`.
- `NotoColorEmoji.ttf`: `pkgs.noto-fonts-color-emoji`.

All sources are Nix build outputs referenced by the Home Manager generation.
No downloaded font files, hard-coded store hashes or writes to `/usr/share/fonts`
are required. Existing Debian fonts remain as fallback.

## Why extract CJK faces?

Botmux 3.52.0 registers files using `@napi-rs/canvas`. Direct TTC registration
exposes the first JP face, while the screenshot font stack requests
`Noto Sans Mono CJK SC`. `extract-botmux-cjk.py` selects the SC mono face by its
internal family name, checks its static Regular/Bold style, and writes a real
single-face OTF. It fails closed if upstream package layout or family changes.

Do not substitute a renamed Nerd Font: its internal family differs from
`JetBrains Mono`. These links migrate ordinary Latin/CJK/emoji font sources;
Nerd PUA glyphs and terminal Unicode width/ZWJ handling need separate work.

## Check and activate

```sh
# Evaluation only: exact targets, safe flags, Nix sources and other-host isolation.
just test-botmux-fonts
```

The check outputs `fontBundle`/`homeFiles` store paths and their `.drv` paths.
Realize the derivations without activating to verify all upstream font files and
the assembled links:

```sh
nix eval --json --accept-flake-config --impure \
  --file scripts/tests/test-botmux-fonts.nix \
  | jq -r '.fontBundleDrv, .homeFilesDrv' \
  | xargs nix-store --realise
```

The CJK extractor also has a standalone regression test (run with a Python
environment containing `fonttools`):

```sh
python3 -B scripts/tests/test-botmux-cjk.py /nix/store/...-devbox-botmux-fonts
```

It checks real family/style/CJK coverage and rejects missing, wrong-family,
duplicate and wrong-style collections; it only writes temporary test files.

After review and explicit activation approval, `just build-devbox` builds and
switches both System Manager and integrated Home Manager. The recipe checks the
system-level Home Manager service. Conflicting existing files are not forcibly
overwritten.

Already-running Botmux workers cache font registration. Coordinate a safe
worker restart or use a new session for runtime verification; do not restart
active conversations just to apply a font change. Confirm the loaded font paths
in `/proc/PID/maps` point to Nix outputs and inspect the real Feishu screenshot.
Changing font files does not itself fix emoji cell widths or ZWJ shaping.
