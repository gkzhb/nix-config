{
  lib,
  stdenv,
  rustPlatform,
  fetchCrate,
  git,
}:

rustPlatform.buildRustPackage rec {
  pname = "cccc-cli";
  version = "1.8.3";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-zWt7XGuTnbDZYYiohpSnzKylCvgKztk3zbFI2oItDlI=";
  };

  cargoHash = "sha256-4MkN5D+jP74hmL/S47TwGkpIXXjM6OD/1hQPy8KkRSY=";

  # ruby-prism-sys generates its C bindings with libclang at build time.
  nativeBuildInputs = [ rustPlatform.bindgenHook ];
  nativeCheckInputs = [ git ];

  # ruby-prism-sys sets target-specific bindgen args, shadowing the hook's
  # generic args. Keep the Linux libc headers available in that override.
  env = lib.optionalAttrs stdenv.hostPlatform.isLinux {
    "BINDGEN_EXTRA_CLANG_ARGS_${stdenv.hostPlatform.rust.rustcTarget}" =
      "-isystem ${stdenv.cc.libc.dev}/include";
  };

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/cccc --version | grep -Fx "cccc ${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Cognitive and cyclomatic complexity analyzer for multiple languages";
    homepage = "https://github.com/moznion/cccc";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "cccc";
  };
}
