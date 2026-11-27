{
  lib,
  fetchurl,
  appimageTools,
  makeDesktopItem,
}:

let
  pname = "browseros-neo";
  version = "0.52.1.1";
  # Upstream publishes Neo point releases as assets on an earlier tag.
  releaseTag = "browserclaw/v0.52.0";
  src = fetchurl {
    url = "https://github.com/browseros-ai/BrowserOS/releases/download/${releaseTag}/BrowserOS_neo_v${version}_x64.AppImage";
    hash = "sha256-xiwFDB/Wdih7EbIDKUqwXI7mrYrvojaarb2gs34aE3k=";
  };
  extracted = appimageTools.extract { inherit pname version src; };
  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "BrowserOS neo";
    exec = "${pname} %U";
    icon = pname;
    categories = [
      "Network"
      "WebBrowser"
    ];
  };
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
    install -Dm644 ${desktopItem}/share/applications/${pname}.desktop \
      $out/share/applications/${pname}.desktop
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
