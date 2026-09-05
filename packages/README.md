# Local ALVR master package

`alvr.nix` builds the Linux streamer from a pinned upstream `master` commit,
including its OpenVR submodule and the ALVR-patched FFmpeg 8.1 libraries. It is
exported as `packages.x86_64-linux.alvr` and as `pkgs.alvr-master` in the local
overlay. It does not replace nixpkgs' `pkgs.alvr` automatically.

## Build

```sh
just build-alvr
```

The recipe uses `.#alvr`, so the flake source includes only Git-tracked files,
with their current working-tree contents. Add new package files to Git before
building; committing them is not required. Untracked and ignored local files
are not included in the flake source snapshot. The first build compiles FFmpeg
and Rust dependencies and can take a while. The recipe limits compilation to
four cores and one derivation at a time.

After a successful build, the dashboard is at `./result/bin/alvr_dashboard`.
Exit the existing ALVR and SteamVR processes before using it. Starting this
dashboard can update the registered SteamVR driver and compositor wrapper; the
package build itself does not modify SteamVR or activate a NixOS configuration.

This is a **21.x development build**, not the 20.14.1 stable release. Use a
compatible headset client, preferably from the same upstream revision. Back up
`~/.config/alvr` before switching versions. This package does not build an Android
APK.

## NixOS use

`zhb-nixos` opts in without importing the entire local overlay:

```nix
{ pkgs, ... }:
{
  # Path shown relative to hosts/zhb-nixos/configuration.nix.
  programs.alvr.package = pkgs.callPackage ../../packages/alvr.nix { };
}
```

`programs.alvr.enable` and the existing firewall configuration are retained.
Other hosts are not switched to this development package.

## Updating the snapshot

1. Select the current `alvr-org/ALVR` master commit; update `rev` and `version`.
2. Prefetch its archive and update the source `hash`.
3. Read that commit's `openvr` gitlink, update `openvrSrc.rev` and its hash.
4. Update `cargoDeps.hash` using the hash reported by Nix after temporarily
   setting it to `lib.fakeHash`.
5. Check upstream `alvr/xtask/src/dependencies.rs` and `alvr/xtask/patches` for
   changes to FFmpeg, Vulkan headers and build requirements, then rebuild.

All sources and Cargo dependencies are hash-pinned; building does not follow a
moving branch or download dependencies from inside the compilation sandbox.
