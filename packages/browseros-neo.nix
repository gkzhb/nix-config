{
  lib,
  fetchurl,
  appimageTools,
}:

let
  pname = "browseros-neo";
  version = "0.51.2.3";
  src = fetchurl {
    # Official neo release, not the mutable CDN or the human-driven BrowserOS.
    url = "https://github.com/browseros-ai/BrowserOS/releases/download/browserclaw/v${version}/BrowserOS_neo_v${version}_x64.AppImage";
    hash = "sha256-YC8/42tzZqXrMviU4f/CSgNGnUN3Guj38uyRiuchFnY=";
  };
  extracted = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  # The FHS rootfs hides the Debian host's /usr/share/fonts.
  extraPkgs = pkgs: [
    pkgs.dejavu_fonts
    pkgs.noto-fonts-cjk-sans
  ];
  extraInstallCommands = ''
    install -Dm644 ${extracted}/usr/share/icons/hicolor/256x256/apps/browserclaw.png \
      $out/share/icons/hicolor/256x256/apps/browseros-neo.png
  '';
  meta = {
    description = "BrowserOS neo, the browser for AI agents";
    homepage = "https://github.com/browseros-ai/BrowserOS";
    # Binary licensing is unclear (https://www.browseros.com/terms); be conservative.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "browseros-neo";
  };
}
