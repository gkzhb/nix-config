{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "alvr-cargo-apk";
  version = "0.10.0-unstable-2025-10-27";
  src = fetchFromGitHub {
    owner = "zarik5";
    repo = "cargo-apk";
    rev = "0fd3126dad5aa1c5f0f26cdae3410f2e5af62c60";
    hash = "sha256-2LKRmKo5Hm3RUa9y/xzwFCMOIPY1Nopki9T7DCosIR8=";
  };

  # The fork does not commit Cargo.lock. Keep our resolved tool dependencies
  # in the repository; remove examples from the workspace before using it.
  cargoLock.lockFile = ./alvr-cargo-apk.lock;
  postPatch = ''
    substituteInPlace Cargo.toml --replace-fail '    "ndk-examples",' ""
    cp ${./alvr-cargo-apk.lock} Cargo.lock
    # This fork's CLI cannot forward --locked. Enforce it on the real Cargo
    # build command rather than passing an unsupported cargo-apk argument.
    substituteInPlace cargo-apk/src/apk.rs \
      --replace-fail 'cargo.arg("build");' 'cargo.arg("build").arg("--locked");'
  '';
  cargoBuildFlags = [
    "-p"
    "cargo-apk"
  ];
  # ndk-build integration tests require an installed Android SDK.
  cargoTestFlags = [
    "-p"
    "cargo-apk"
  ];

  meta = {
    description = "Pinned cargo-apk fork used by ALVR";
    homepage = "https://github.com/zarik5/cargo-apk";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "cargo-apk";
    platforms = [ "x86_64-linux" ];
  };
}
