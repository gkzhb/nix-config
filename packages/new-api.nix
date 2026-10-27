{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  cacert,
  python3,
}:

let
  version = "1.0.0-rc.47";
  # Hashes from the tagged release's checksums-linux.txt/checksums-macos.txt.
  releases = {
    x86_64-linux = {
      filename = "new-api-v${version}";
      hash = "sha256-mGLety6VZ/rZQ9DvrcIgZ/SLNsML+TU2h0wJdkZ8U0w=";
    };
    aarch64-linux = {
      filename = "new-api-arm64-v${version}";
      hash = "sha256-z2Z7a4LUBa34xRrlsLPBel+wyZQ/vFPN/RaFtRfCqYw=";
    };
    aarch64-darwin = {
      filename = "new-api-macos-v${version}";
      hash = "sha256-9YWaihjQexPX/dexdUFuIh5z1JQFbddkOZm6MKhG85E=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
  releaseBinary = fetchurl {
    url = "https://github.com/QuantumNous/new-api/releases/download/v${version}/${release.filename}";
    inherit (release) hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "new-api";
  inherit version;

  # The tagged source archive supplies the required license/attribution files.
  # The upstream release binary already embeds the built frontend.
  src = fetchurl {
    url = "https://github.com/QuantumNous/new-api/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-bnGAUcpcdTAFvpN4QlUXUjxJ/k1jRbVy76giok3+o5E=";
  };

  # Despite upstream's static-link flags, Linux releases have a glibc interpreter
  # and DT_NEEDED libc.so.6; patch them instead of relying on host nix-ld.
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.libc ];
  nativeInstallCheckInputs = [ python3 ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ${releaseBinary} $out/bin/new-api
    install -Dm644 -t $out/share/doc/new-api LICENSE NOTICE THIRD-PARTY-LICENSES.md
    wrapProgram $out/bin/new-api \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt

    runHook postInstall
  '';

  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    python3 ${../scripts/tests/test-new-api.py} $out/bin/new-api ${version}
    runHook postInstallCheck
  '';

  meta = {
    description = "LLM gateway and AI asset management system with an embedded Web UI";
    homepage = "https://github.com/QuantumNous/new-api";
    changelog = "https://github.com/QuantumNous/new-api/releases/tag/v${version}";
    # Additional attribution requirements under AGPLv3 Section 7 are in NOTICE.
    license = lib.licenses.agpl3Only;
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "new-api";
  };
}
