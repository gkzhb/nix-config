{
  lib,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "knots";
  version = "1.18.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-Qh97ZDbpJJ4JhRKclxjwE3xNmSZSBRTc4U9Me7GjoMU=";
  };

  cargoHash = "sha256-upoIbnhLQSodwv2yR2inDvlcF0Yqf7Nj2aof4JRy4zA=";

  # The published crate omits the sample-files/rust_crate fixture.
  checkFlags = [ "--skip=tests::rust_fixture_crate_file_ce" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/knots --version | grep -Fx "knots ${version}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Multi-language code complexity analyzer";
    homepage = "https://github.com/brandon-arrendondo/knots";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "knots";
  };
}
