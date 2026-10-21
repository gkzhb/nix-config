{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  git,
}:

let
  version = "0.1.0-rc21";
  # Hashes from the tagged release's SHA256SUMS.
  releases = {
    x86_64-linux = {
      platform = "linux_amd64";
      hash = "sha256-TA2X9Iq7CWxMudar6AjZEN0M/zm2G8ew6nvkdAu0IvU=";
    };
    aarch64-linux = {
      platform = "linux_arm64";
      hash = "sha256-qtnqJY36NSCc5ssmaax0D7M2fpcvKFmzxw6Nv4wNrJo=";
    };
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "sha256-0RdUqwn4+zYRxG9aLFLJzmU+zsxxH3ByN86mLRT4CPg=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "aoci-code";
  inherit version;

  # Upstream requires Go 1.26.9, newer than the locked nixpkgs toolchain.
  src = fetchurl {
    url = "https://github.com/aoci-spec/aoci-code/releases/download/v${version}/aoci_${version}_${release.platform}.tar.gz";
    inherit (release) hash;
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 aoci $out/bin/aoci
    install -Dm644 -t $out/share/doc/aoci-code \
      LICENSE NOTICE PATENTS THIRD-PARTY-NOTICES TRADEMARKS \
      README.md README.zh-CN.md CHANGELOG.md
    cp -r assets $out/share/doc/aoci-code/assets
    wrapProgram $out/bin/aoci --prefix PATH : ${lib.makeBinPath [ git ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/aoci --version | grep -F "aoci version ${version} (commit "
    $out/bin/aoci --help > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Local-first MCP server and CLI for persistent codebase knowledge";
    homepage = "https://github.com/aoci-spec/aoci-code";
    changelog = "https://github.com/aoci-spec/aoci-code/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.fsl11Mit;
    platforms = builtins.attrNames releases;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "aoci";
  };
}
