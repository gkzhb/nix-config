{ pkgs }:
let
  snapshot = pkgs.callPackage ./alvr-source.nix { };
  cargoApk = pkgs.callPackage ./alvr-cargo-apk.nix { };
  rust = pkgs.rust-bin.stable."1.97.1".minimal.override {
    targets = [ "aarch64-linux-android" ];
  };
  ndkVersion = "26.1.10909125"; # r26b, as used by upstream CI
  buildToolsVersion = "34.0.0";
  android = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [ "32" ];
    buildToolsVersions = [ buildToolsVersion ];
    platformToolsVersion = "37.0.1";
    cmdLineToolsVersion = "13.0";
    toolsVersion = "26.1.1";
    includeNDK = true;
    ndkVersions = [ ndkVersion ];
    includeCmake = false;
    includeEmulator = false;
    includeSystemImages = false;
    includeSources = false;
    extraLicenses = [ ];
  };
  sdk = "${android.androidsdk}/libexec/android-sdk";
  openxrLoader = pkgs.fetchurl {
    url = "https://github.com/KhronosGroup/OpenXR-SDK-Source/releases/download/release-1.1.36/openxr_loader_for_android-1.1.36.aar";
    hash = "sha256-e7jvN/f+E4IzmYxkUp4ICO4z9YiYam5UqQFavEC0S+c=";
  };
  cargoVendor = pkgs.rustPlatform.fetchCargoVendor {
    inherit (snapshot) src;
    hash = snapshot.cargoHash;
  };
  # Replace the placeholder once, keeping the upstream alias in the writable
  # workspace. Cargo's offline mode applies to xtask's child cargo processes too.
  vendorConfig = pkgs.runCommand "alvr-android-cargo-config" { } ''
    substitute ${cargoVendor}/.cargo/config.toml $out \
      --subst-var-by vendor ${cargoVendor}
  '';
  driver = pkgs.writeShellApplication {
    name = "alvr-android";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gnugrep
      unzip
      python3
      util-linux
    ];
    text = builtins.readFile ../scripts/alvr-android.sh;
  };
in
pkgs.mkShell {
  name = "alvr-android";
  packages = [
    rust
    cargoApk
    android.androidsdk
    pkgs.jdk17
    pkgs.pkg-config
    pkgs.cmake
    pkgs.ninja
    driver
  ];
  # Host build dependencies; Android compiler/linker are selected by cargo-apk.
  buildInputs = [ pkgs.openssl ];
  JAVA_HOME = "${pkgs.jdk17}";
  ANDROID_HOME = sdk;
  ANDROID_SDK_ROOT = sdk;
  ANDROID_NDK_HOME = "${sdk}/ndk/${ndkVersion}";
  ANDROID_NDK_ROOT = "${sdk}/ndk/${ndkVersion}";
  ANDROID_NDK_PATH = "${sdk}/ndk/${ndkVersion}";
  ALVR_ANDROID_BUILD_TOOLS = "${sdk}/build-tools/${buildToolsVersion}";
  ALVR_ANDROID_REV = snapshot.rev;
  ALVR_ANDROID_SRC = toString snapshot.src;
  ALVR_ANDROID_OPENVR = toString snapshot.openvrSrc;
  ALVR_ANDROID_OPENXR = toString openxrLoader;
  ALVR_ANDROID_VENDOR_CONFIG = toString vendorConfig;
  # Absolute tools prevent a pre-existing rustup override selecting another Rust.
  RUSTC = "${rust}/bin/rustc";
  RUSTDOC = "${rust}/bin/rustdoc";
  CARGO_NET_OFFLINE = "true";

  passthru = {
    inherit
      cargoApk
      rust
      android
      driver
      ;
  };
  shellHook = ''
    echo "ALVR Quest 2 ${snapshot.rev}: alvr-android prepare|build|verify [work-dir]"
    echo "SDK licenses are accepted only in this Android-specific package set."
  '';
}
