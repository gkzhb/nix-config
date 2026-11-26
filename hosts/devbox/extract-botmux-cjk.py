"""Extract static Simplified-Chinese mono faces for Botmux's Canvas loader."""

import sys
from pathlib import Path

from fontTools.ttLib import TTCollection


def extract(source_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for style in ("Regular", "Bold"):
        source = source_dir / f"NotoSansCJK-{style}.ttc"
        collection = TTCollection(source)
        try:
            matches = [
                font
                for font in collection.fonts
                if font["name"].getDebugName(1) == "Noto Sans Mono CJK SC"
            ]
            if len(matches) != 1:
                raise ValueError(
                    f"Expected one Noto Sans Mono CJK SC face in {source}; found {len(matches)}"
                )
            font = matches[0]
            if "fvar" in font:
                raise ValueError(
                    f"Expected a static font, got variable face in {source}"
                )
            if font["name"].getDebugName(2) != style:
                raise ValueError(f"Unexpected style in {source}")
            font.save(output_dir / f"NotoSansMonoCJKsc-{style}.otf")
        finally:
            collection.close()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("Usage: extract-botmux-cjk.py SOURCE_DIR OUTPUT_DIR")
    extract(Path(sys.argv[1]), Path(sys.argv[2]))
