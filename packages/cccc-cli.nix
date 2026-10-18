{
  lib,
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

  nativeCheckInputs = [ git ];

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
