"""Check the extracted Botmux CJK faces and fail-closed malformed collections."""

import importlib.util
import sys
import tempfile
from pathlib import Path

from fontTools.ttLib import TTCollection, TTFont


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location(
        "extractor", root / "hosts/devbox/extract-botmux-cjk.py"
    )
    extractor = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(extractor)
    bundle = Path(sys.argv[1])
    for style in ("Regular", "Bold"):
        with TTFont(bundle / f"NotoSansMonoCJKsc-{style}.otf") as font:
            assert font["name"].getDebugName(1) == "Noto Sans Mono CJK SC"
            assert font["name"].getDebugName(2) == style
            assert "fvar" not in font
            assert ord("中") in font.getBestCmap()
    with tempfile.TemporaryDirectory(prefix="botmux-font-test-") as directory:
        directory = Path(directory)
        for case in ("missing", "wrong-family", "duplicate", "wrong-style"):
            source = directory / case
            source.mkdir()
            collection = TTCollection()
            if case != "missing":
                font = TTFont(bundle / "NotoSansMonoCJKsc-Regular.otf")
                if case == "wrong-family":
                    for record in font["name"].names:
                        if record.nameID == 1:
                            record.string = "Other Family".encode(record.getEncoding())
                elif case == "wrong-style":
                    for record in font["name"].names:
                        if record.nameID == 2:
                            record.string = "Italic".encode(record.getEncoding())
                collection.fonts = [font, font] if case == "duplicate" else [font]
            collection.save(source / "NotoSansCJK-Regular.ttc")
            collection.close()
            try:
                extractor.extract(source, directory / "output")
            except ValueError:
                pass
            else:
                raise AssertionError(f"{case} collection unexpectedly accepted")
    print("PASS: SC family/style/CJK coverage; malformed collections rejected")


if __name__ == "__main__":
    main()
