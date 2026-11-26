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

  # fetchCargoVendor uses Python requests, not Cargo's HTTP timeout settings.
  # Allow slow proxy/TLS setup without changing the downloader for other packages.
  depsExtraArgs.preBuild = ''
    fetcherDir="$TMPDIR/cccc-cargo-fetcher"
    mkdir -p "$fetcherDir"
    cp "$(command -v fetch-cargo-vendor-util)" "$fetcherDir/fetch-cargo-vendor-util"
    chmod u+w "$fetcherDir/fetch-cargo-vendor-util"
    substituteInPlace "$fetcherDir/fetch-cargo-vendor-util" \
      --replace-fail 'CONNECT_TIMEOUT = 2  #' 'CONNECT_TIMEOUT = 30  #' \
      --replace-fail 'READ_TIMEOUT = 10  #' 'READ_TIMEOUT = 30  #'
    chmod u-w "$fetcherDir/fetch-cargo-vendor-util"
    export PATH="$fetcherDir:$PATH"
  '';

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
