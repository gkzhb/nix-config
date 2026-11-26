{ pkgs, lib, ... }:

let
  # Botmux's Canvas loader expects static SC faces and these exact filenames.
  # Registering a TTC directly exposes its first (JP) face, not the SC family.
  cjk = pkgs.noto-fonts-cjk-sans.override { static = true; };
  python = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
  fonts = pkgs.runCommand "devbox-botmux-fonts" { nativeBuildInputs = [ python ]; } ''
    mkdir -p "$out"
    ln -s ${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf "$out/JetBrainsMono-Regular.ttf"
    ln -s ${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Bold.ttf "$out/JetBrainsMono-Bold.ttf"
    ln -s ${pkgs.noto-fonts-color-emoji}/share/fonts/noto/NotoColorEmoji.ttf "$out/NotoColorEmoji.ttf"

    python ${./extract-botmux-cjk.py} \
      ${cjk}/share/fonts/opentype/noto-cjk \
      "$out"

    for font in "$out"/*; do
      test -s "$font"
    done
  '';
  names = [
    "JetBrainsMono-Regular.ttf"
    "JetBrainsMono-Bold.ttf"
    "NotoSansMonoCJKsc-Regular.otf"
    "NotoSansMonoCJKsc-Bold.otf"
    "NotoColorEmoji.ttf"
  ];
in
{
  # Imported only by hosts/devbox/user.nix. Do not put in shared dotfiles.
  # Keep individual, non-forced links: never overwrite unrelated Botmux data.
  home.file = lib.genAttrs (map (name: ".botmux/fonts/${name}") names) (target: {
    source = "${fonts}/${baseNameOf target}";
  });
}
