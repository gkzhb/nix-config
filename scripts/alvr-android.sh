# Sourced into a Nix writeShellApplication; all tool/source paths come from the shell.
usage() {
    echo "Usage: alvr-android prepare|build|verify [work-dir]" >&2
    exit 2
}
[[ $# -ge 1 && $# -le 2 ]] || usage
mode=$1
case "$mode" in prepare|build|verify) ;; *) usage ;; esac
: "${ALVR_ANDROID_REV:?Enter nix develop .#alvr-android first}"
: "${ALVR_ANDROID_SRC:?}" "${ALVR_ANDROID_OPENVR:?}" "${ALVR_ANDROID_OPENXR:?}"
: "${ALVR_ANDROID_VENDOR_CONFIG:?}" "${ALVR_ANDROID_BUILD_TOOLS:?}"
ALVR_ANDROID_VERSION=$(python3 - "$ALVR_ANDROID_SRC/Cargo.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    print(tomllib.load(f)['workspace']['package']['version'])
PY
)
export ALVR_ANDROID_VERSION

umask 077
work=$(realpath -m -- "${2:-.alvr-android/$ALVR_ANDROID_REV}")
case "$work" in /nix/store|/nix/store/*|/) echo "Use a writable work directory outside the Nix store." >&2; exit 1 ;; esac
mkdir -p -- "$(dirname -- "$work")"
# Serialize prepare/build/verify for this workspace, including initial creation.
exec 9>"$work.lock"
flock 9

inputs() {
    printf '%s\n' "$ALVR_ANDROID_REV" "$ALVR_ANDROID_SRC" "$ALVR_ANDROID_OPENVR" \
        "$ALVR_ANDROID_OPENXR" "$ALVR_ANDROID_VENDOR_CONFIG" "workspace-format=2"
}
check_workspace() {
    if [[ ! -f "$work/.alvr-inputs" ]] || ! cmp -s "$work/.alvr-inputs" <(inputs); then
        echo "Workspace absent or inputs changed: $work" >&2
        echo "Run prepare with a new directory. Existing directories are never overwritten." >&2
        exit 1
    fi
    cmp -- "$work/Cargo.lock" "$ALVR_ANDROID_SRC/Cargo.lock"
}
prepare() (
    if [[ -e "$work" ]]; then
        check_workspace
        echo "Already prepared: $work"
        return
    fi
    local temp
    temp=$(mktemp -d "$work.prepare.XXXXXX")
    # Keep failures from leaving a directory that looks ready to build.
    trap 'rm -rf -- "$temp"' EXIT
    cp -r --no-preserve=mode -- "$ALVR_ANDROID_SRC/." "$temp/"
    chmod -R u+w -- "$temp"
    mkdir -p "$temp/openvr" "$temp/deps/android_openxr/arm64-v8a" "$temp/.cargo"
    cp -r --no-preserve=mode -- "$ALVR_ANDROID_OPENVR/." "$temp/openvr/"
    unzip -p "$ALVR_ANDROID_OPENXR" \
        prefab/modules/openxr_loader/libs/android.arm64-v8a/libopenxr_loader.so \
        > "$temp/deps/android_openxr/arm64-v8a/libopenxr_loader.so"
    test -s "$temp/deps/android_openxr/arm64-v8a/libopenxr_loader.so"
    # Keep the source alias and provide only the pinned registry/git dependencies.
    printf '\n' >> "$temp/.cargo/config.toml"
    cat "$ALVR_ANDROID_VENDOR_CONFIG" >> "$temp/.cargo/config.toml"
    inputs > "$temp/.alvr-inputs"
    mv -- "$temp" "$work"
    trap - EXIT
    echo "Prepared: $work"
)
verify() {
    check_workspace
    local apk="$work/build/alvr_client_android/alvr_client_android.apk"
    test -s "$apk"
    "$ALVR_ANDROID_BUILD_TOOLS/apksigner" verify --verbose --print-certs "$apk"
    "$ALVR_ANDROID_BUILD_TOOLS/aapt" dump badging "$apk" > "$apk.badging.txt"
    python3 - "$apk" <<'PY'
import os, pathlib, re, struct, sys, zipfile
apk = pathlib.Path(sys.argv[1])
badging = pathlib.Path(str(apk) + '.badging.txt').read_text()
assert re.search(r"^package: name='alvr.client.dev'", badging, re.M), badging
assert "versionName='" + os.environ['ALVR_ANDROID_VERSION'] + "'" in badging, badging
assert "sdkVersion:'28'" in badging and "targetSdkVersion:'32'" in badging, badging
with zipfile.ZipFile(apk) as z:
    libs = {p for p in z.namelist() if p.startswith('lib/') and p.endswith('.so')}
    assert libs and all(p.startswith('lib/arm64-v8a/') for p in libs), libs
    for name in ['libalvr_client_openxr.so', 'libopenxr_loader.so']:
        assert 'lib/arm64-v8a/' + name in libs, (name, libs)
    for name in libs:
        with z.open(name) as lib:
            header = lib.read(20)
        assert header[:6] == b'\x7fELF\x02\x01', (name, 'not ELF64 little-endian')
        assert struct.unpack_from('<H', header, 18)[0] == 183, (name, 'not AArch64')
print('Verified: alvr.client.dev, ARM64 only, min SDK 28, target SDK 32, OpenXR loader bundled')
PY
    sha256sum -- "$apk"
    echo "APK: $apk"
}
case "$mode" in
    prepare) prepare ;;
    verify) verify ;;
    build)
        check_workspace
        # Do not reuse ~/.cargo configuration, rustup overrides or host target flags.
        export CARGO_HOME="$work/.cargo-home"
        export CARGO_TARGET_DIR="$work/target"
        export CARGO_NET_OFFLINE=true
        unset RUSTFLAGS CARGO_ENCODED_RUSTFLAGS CARGO_BUILD_TARGET RUSTC_WRAPPER RUSTC_WORKSPACE_WRAPPER
        mkdir -p "$CARGO_HOME"
        if [[ -n ${CARGO_APK_RELEASE_KEYSTORE:-} ]]; then
            : "${CARGO_APK_RELEASE_KEYSTORE_PASSWORD:?Set both custom keystore variables}"
            export CARGO_APK_RELEASE_KEYSTORE
            CARGO_APK_RELEASE_KEYSTORE=$(realpath -e -- "$CARGO_APK_RELEASE_KEYSTORE")
            case "$CARGO_APK_RELEASE_KEYSTORE" in /nix/store/*) echo "Signing keys must not be stored in the Nix store." >&2; exit 1 ;; esac
        else
            # Development signing only. Stable across source revisions and workspace cleanup.
            keydir="${XDG_DATA_HOME:-$HOME/.local/share}/alvr-android"
            mkdir -p -- "$keydir"
            keydir=$(realpath -e -- "$keydir")
            case "$keydir" in /nix/store/*) echo "Signing keys must not be stored in the Nix store." >&2; exit 1 ;; esac
            export CARGO_APK_RELEASE_KEYSTORE="$keydir/debug.keystore"
            export CARGO_APK_RELEASE_KEYSTORE_PASSWORD=android
            (
                flock 8
                if [[ ! -e "$CARGO_APK_RELEASE_KEYSTORE" ]]; then
                    "$JAVA_HOME/bin/keytool" -genkeypair -noprompt -storetype JKS \
                        -keystore "$CARGO_APK_RELEASE_KEYSTORE" -storepass android -keypass android \
                        -alias androiddebugkey -dname 'CN=ALVR Local Development,O=Android,C=US' \
                        -keyalg RSA -keysize 2048 -validity 10000
                    chmod 600 "$CARGO_APK_RELEASE_KEYSTORE"
                fi
            ) 8>"$keydir/.key.lock"
        fi
        cd -- "$work"
        cargo run --locked -p alvr_xtask -- build-client --release
        verify
        ;;
esac
