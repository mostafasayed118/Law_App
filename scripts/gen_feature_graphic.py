"""Generate the LegalHub Google Play listing graphics from the brand palette.

Reproducible brand-asset tooling, companion to scripts/gen_launcher_icons.py
(same D-01 tokens, same scales-of-justice glyph). Outputs (overwrites in
place):

  store_assets/feature_graphic.png   1024x500 RGB — the Play Console
                                     "feature graphic"; must be opaque
  store_assets/play_icon_512.png     512x512 opaque square — the Play
                                     Console listing icon

Run (managed venv):
  python scripts/gen_feature_graphic.py

Deps: pillow (text rendering uses the bundled brand fonts under
assets/fonts/ — Playfair Display wordmark, Noto Sans tagline).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Import the glyph + tokens from the launcher-icon generator (same dir).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_launcher_icons import GOLD, NAVY, REPO, draw_scales  # noqa: E402

W, H = 1024, 500
FONTS = REPO / "assets" / "fonts"
OUT_DIR = REPO / "store_assets"

TAGLINE = "Consultations · Matters · Documents · Messaging"
PALE = (0xC9, 0xD4, 0xDD)  # muted slate for the tagline on navy


def _font(path: Path, size: int, variation: str | None = None) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(str(path), size)
    if variation is not None:
        try:
            f.set_variation_by_name(variation)  # variable-font named instance
        except Exception:
            pass  # fall back to the default (Regular) instance
    return f


def _fit(path: Path, text: str, max_width: float, start: int,
         variation: str | None = None) -> ImageFont.FreeTypeFont:
    """Largest font size <= start whose rendering of `text` fits max_width."""
    size = start
    while size > 10:
        f = _font(path, size, variation)
        if ImageDraw.Draw(Image.new("RGB", (1, 1))).textlength(
                text, font=f) <= max_width:
            return f
        size -= 2
    return _font(path, 10, variation)


def feature_graphic() -> Image.Image:
    img = Image.new("RGB", (W, H), NAVY[:3])
    d = ImageDraw.Draw(img)

    # Thin gold hairline frame — quiet, not a border motif.
    m = 14
    d.rounded_rectangle([m, m, W - m, H - m], radius=18, outline=GOLD, width=3)

    # Glyph block on the left, vertically centered.
    glyph = 290
    draw_scales(d, 92, (H - glyph) / 2, glyph)

    # Wordmark + tagline to the right of the glyph, shrink-to-fit.
    playfair = FONTS / "playfair_display" / "PlayfairDisplay-Variable.ttf"
    noto = FONTS / "noto_sans" / "NotoSans-Variable.ttf"
    tx = 92 + glyph + 56
    avail = W - 40 - tx
    title = _fit(playfair, "LegalHub", avail, 100, variation="Bold")
    tag = _fit(noto, TAGLINE, avail, 34)
    d.text((tx, H * 0.44), "LegalHub", font=title, fill=GOLD, anchor="lm")
    d.text((tx, H * 0.62), TAGLINE, font=tag, fill=PALE, anchor="lm")
    return img


def play_icon(size: int = 512) -> Image.Image:
    """Opaque navy square + glyph — the Play Console listing icon."""
    img = Image.new("RGB", (size, size), NAVY[:3])
    draw_scales(ImageDraw.Draw(img), 0, 0, size)
    return img


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)

    fg = OUT_DIR / "feature_graphic.png"
    feature_graphic().save(fg, format="PNG")
    print(f"wrote {fg.relative_to(REPO)} ({W}x{H}, RGB opaque)")

    icon = OUT_DIR / "play_icon_512.png"
    play_icon().save(icon, format="PNG")
    print(f"wrote {icon.relative_to(REPO)} (512x512, RGB opaque)")


if __name__ == "__main__":
    main()
