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
APK; the separate [Quest 2 development workflow](#quest-2-android-client) below does.

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

1. In `alvr-source.nix`, select the current `alvr-org/ALVR` master commit;
   update `rev` and `version`. PC and Android share this definition.
2. Prefetch its archive and update the source `hash`.
3. Read that commit's `openvr` gitlink, update `openvrSrc.rev` and its hash.
4. Update `cargoHash` in `alvr-source.nix` using the hash reported by Nix after
   temporarily setting it to `lib.fakeHash`. Both workflows use this vendor set.
5. Check upstream `alvr/xtask/src/dependencies.rs` and `alvr/xtask/patches` for
   changes to FFmpeg, Vulkan headers and build requirements, then rebuild.

All sources and Cargo dependencies are hash-pinned; building does not follow a
moving branch or download dependencies from inside the compilation sandbox.

## Quest 2 Android client

The Android workflow builds an **ARM64 `alvr.client.dev` APK**, using the same
ALVR revision as the PC package. The build host must be `x86_64-linux`; this does
not refer to the headset's architecture. No connected headset, SteamVR, GPU,
system activation or root access is required to compile.

### Tools and licenses

`devShells.x86_64-linux.alvr-android` provides:

- Rust 1.97.1 with `aarch64-linux-android` std, via the locked rust-overlay input.
- JDK 17, Android SDK Platform 32, build-tools 34.0.0, NDK r26b (26.1.10909125),
  platform-tools 37.0.1 and command-line tools 13.0, via locked nixpkgs.
- ALVR's cargo-apk fork at `0fd3126dad5aa1c5f0f26cdae3410f2e5af62c60`, with
  dependencies pinned in `alvr-cargo-apk.lock`. This is not nixpkgs' release.
- Khronos OpenXR loader 1.1.36 for ARM64. Quest 2 uses the generic loader;
  Quest 1/Pico/YVR-specific loaders are deliberately omitted.

This Android-only package set sets `android_sdk.accept_license = true` and
allows Android SDK packages; it does **not** change other hosts' license
configuration. Review the [Android SDK license](https://developer.android.com/studio/terms)
before using it. No emulator, system images or extra vendor licenses are enabled.
The initial Nix realization needs network access and several GB of disk space.
It does not run `sdkmanager`, `rustup target add`, `cargo install` or upstream
`prepare-deps` against your user environment.

### Prepare, build, verify

```sh
just prepare-alvr-android
just build-alvr-android
# Recheck an existing APK without rebuilding:
just verify-alvr-android
```

Preparation copies the pinned sources to `.alvr-android/<rev>/` (Git-ignored),
adds the OpenVR submodule and OpenXR loader, and configures the pinned Cargo
vendor dependencies. It never overwrites an existing workspace with different
inputs. The build is `cargo run --locked -p alvr_xtask -- build-client --release`.
The pinned cargo-apk package is patched to add `--locked` to its child Cargo
build command (its own CLI cannot accept that flag). Cargo operates offline,
with its own writable home and target directory.

Output:

```text
.alvr-android/<rev>/build/alvr_client_android/alvr_client_android.apk
```

Verification checks the APK signature, package ID, source version, min/target
SDK (28/32), ARM64 library paths and ELF headers, and the presence of the client and OpenXR
loader. It prints the signer certificate and APK SHA-256. This is not a headset
streaming test.

`just test-alvr-android` runs sandboxed workspace regression tests without the
SDK: preparation, idempotence, input mismatch, cleanup, store-path rejection,
and APK ABI checks. Its fake SDK fixtures do not validate real signing.

To use a different writable directory or tune Cargo parallelism:

```sh
just alvr-android-shell
alvr-android prepare /path/to/workspace
CARGO_BUILD_JOBS=4 alvr-android build /path/to/workspace
alvr-android verify /path/to/workspace
```

Use a new directory after changing pinned inputs, or explicitly remove the old
workspace yourself. Prepared sources are editable for development; a modified
workspace is no longer an exact upstream-source build. Use a fresh workspace
for validation. Do not point the workspace into `/nix/store`.

### Signing and installation boundary

By default the script creates and reuses a **local development key** at
`${XDG_DATA_HOME:-$HOME/.local/share}/alvr-android/debug.keystore`, outside the
workspace and Nix store. Its public development password is `android`; it is
not a production signing identity. Deleting the workspace does not rotate this
key. Back it up if you need to keep updating installations signed with it.

An existing key can be selected at runtime by providing **both**
`CARGO_APK_RELEASE_KEYSTORE` and `CARGO_APK_RELEASE_KEYSTORE_PASSWORD`. The key
must be outside the Nix store. Do not put a private key or password in Nix
expressions, flake inputs, tracked files or command-line arguments. Manage any
persistent private signing material using sops-nix, decrypt at runtime, and
perform signing outside Nix derivations. This devShell workflow signs outside
the sandbox; a future pure APK derivation should produce an unsigned artifact.

These commands never install, uninstall or launch anything on the headset.
After enabling Quest developer mode, authorizing USB debugging, and confirming
that you want to install, you may manually run:

```sh
adb install -r /absolute/path/to/alvr_client_android.apk
```

An existing `alvr.client.dev` signed by another key cannot be updated with this
local key. Do not automatically uninstall it: that may delete application data.
Stable/store clients may use a different package ID. Keep the PC/client revision
compatible and verify the PC Vulkan loader fix before testing streaming.

### Reproducibility and updating

This is a **Nix-managed devShell workflow**, not `packages.alvr-android` and not
a claim of bit-for-bit reproducible APKs. Toolchains, sources, loader and Cargo
dependencies are pinned, but the writable workspace, signing identity, paths,
and packaging timestamps remain outside Nix's isolated build model.

The initial implementation was validated by building the release APK for
`0b9de252b3e8ad425199453648c11808a473c912`: version `21.0.0-dev12`, package
`alvr.client.dev`, versionCode `18153472`, ARM64 ELF libraries, and valid APK v3
signature. It has **not** been installed or streaming-tested on Quest 2.
A pure unsigned APK derivation can reuse these pinned inputs later; neither
that packaging work nor a separate repository is needed for this workflow.

When updating `alvr-source.nix`, also recheck upstream Android metadata, CI,
`xtask` dependency/build scripts and the OpenXR loader version. When updating
the cargo-apk fork, regenerate `alvr-cargo-apk.lock` from its source with the
`ndk-examples` workspace member removed, then build/test the Nix tool package.
Do not silently use the moving fork branch or replace it with crates.io cargo-apk.
