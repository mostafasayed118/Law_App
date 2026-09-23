"""Generate the LegalHub launcher icons (Android + iOS) from the brand palette.

Reproducible brand-asset tooling: the launcher glyph is a scales-of-justice
mark drawn from the D-01 palette — deep navy #0B1D2E (LegalHubTheme.primary,
the canonical primary per docs/legalhub_specification.md §5.1) on Old Gold
#E9C176 (LegalHubTheme.darkSecondary). The glyph is drawn programmatically so
every density regenerates from one source of truth; no binary asset is
hand-maintained.

Outputs (overwrites in place):

  Android legacy    android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
                    (48/72/96/144/192 — rounded-square navy tile + gold scales)
  Android adaptive  mipmap-*/ic_launcher_foreground.png (108..432, transparent,
                    glyph inside the 66dp safe zone) + mipmap-anydpi-v26/ic_launcher.xml
                    + values/colors.xml (`ic_launcher_background`)
  iOS               ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
                    (every size declared in Contents.json; square, opaque —
                    iOS applies its own mask)

Run (managed venv):
  python scripts/gen_launcher_icons.py

Deps: pillow.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

# D-01 brand tokens (lib/app/legalhub_theme.dart).
NAVY = (0x0B, 0x1D, 0x2E, 0xFF)  # LegalHubTheme.primary
GOLD = (0xE9, 0xC1, 0x76, 0xFF)  # LegalHubTheme.darkSecondary

REPO = Path(__file__).resolve().parent.parent
ANDROID_RES = REPO / "android" / "app" / "src" / "main" / "res"
IOS_APPICON = REPO / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

LEGACY_DENSITIES = {  # dp: 48
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ADAPTIVE_DENSITIES = {  # dp: 108 (foreground canvas)
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}
# (Contents.json size tag, scale) -> pixels, matching the existing filenames.
IOS_SIZES = [
    ("20x20", 1, 20), ("20x20", 2, 40), ("20x20", 3, 60),
    ("29x29", 1, 29), ("29x29", 2, 58), ("29x29", 3, 87),
    ("40x40", 1, 40), ("40x40", 2, 80), ("40x40", 3, 120),
    ("60x60", 2, 120), ("60x60", 3, 180),
    ("76x76", 1, 76), ("76x76", 2, 152),
    ("83.5x83.5", 2, 167),
    ("1024x1024", 1, 1024),
]

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

COLORS_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- D-01 canonical primary; consumed by mipmap-anydpi-v26/ic_launcher.xml -->
    <color name="ic_launcher_background">#0B1D2E</color>
</resources>
"""


def draw_scales(draw: ImageDraw.ImageDraw, x0: float, y0: float, side: float, color=GOLD) -> None:
    """Draw the scales-of-justice glyph into the unit box at (x0, y0, side px).

    Geometry (unit coords inside the box): a finial bead, a centered post, a
    wide beam, two hanger lines, two half-ellipse pans, and a two-bar
    pedestal. Stroke width scales with `side` so every density renders the
    same mark.
    """
    w = max(2, round(side * 0.055))  # master stroke width

    def P(u: float, v: float) -> tuple[float, float]:
        return (x0 + u * side, y0 + v * side)

    # Finial bead.
    r = 0.045
    cx, cy = 0.5, 0.10
    draw.ellipse(
        [P(cx - r, cy - r), P(cx + r, cy + r)],
        fill=color,
    )

    # Post (centered) and beam (wide top bar).
    draw.rectangle([P(0.475, 0.13), P(0.525, 0.78)], fill=color)
    draw.rounded_rectangle([P(0.16, 0.20), P(0.84, 0.245)], radius=w / 2, fill=color)

    # Beam-end caps.
    for ex in (0.19, 0.81):
        draw.ellipse([P(ex - 0.035, 0.2225 - 0.035), P(ex + 0.035, 0.2225 + 0.035)], fill=color)

    # Hanger lines from beam ends down-inward to the pan rims.
    draw.line([P(0.19, 0.245), P(0.245, 0.46)], fill=color, width=w)
    draw.line([P(0.81, 0.245), P(0.755, 0.46)], fill=color, width=w)

    # Pans: bottom half-ellipse bowls (0..180 sweeps through the bottom).
    for pcx in (0.245, 0.755):
        rx, ry = 0.115, 0.085
        bowl = [P(pcx - rx, 0.46 - ry), P(pcx + rx, 0.46 + ry)]
        draw.arc(bowl, start=0, end=180, fill=color, width=w)
        draw.line([P(pcx - rx, 0.46), P(pcx + rx, 0.46)], fill=color, width=w)

    # Pedestal: tapered column + wide foot bar.
    draw.polygon([P(0.42, 0.78), P(0.58, 0.78), P(0.62, 0.86), P(0.38, 0.86)], fill=color)
    draw.rounded_rectangle([P(0.33, 0.875), P(0.67, 0.925)], radius=w / 2, fill=color)


def legacy_icon(size: int) -> Image.Image:
    """Rounded-square navy tile + the gold glyph, for pre-API-26 launchers."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    inset = size * 0.02
    radius = size * 0.225
    d.rounded_rectangle([inset, inset, size - inset, size - inset], radius=radius, fill=NAVY)
    glyph = size * 0.64
    draw_scales(d, (size - glyph) / 2, (size - glyph) / 2, glyph)
    return img


def adaptive_foreground(size: int) -> Image.Image:
    """Transparent 108dp-canvas foreground; glyph inside the 66dp safe zone."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    glyph = size * 0.46
    draw_scales(d, (size - glyph) / 2, (size - glyph) / 2, glyph)
    return img


def ios_icon(size: int) -> Image.Image:
    """Full-bleed opaque navy square + glyph (iOS masks its own corners)."""
    img = Image.new("RGB", (size, size), NAVY[:3])
    d = ImageDraw.Draw(img)
    glyph = size * 0.60
    draw_scales(d, (size - glyph) / 2, (size - glyph) / 2, glyph)
    return img


def main() -> None:
    for folder, px in LEGACY_DENSITIES.items():
        out = ANDROID_RES / folder / "ic_launcher.png"
        legacy_icon(px).save(out)
        print(f"wrote {out.relative_to(REPO)} ({px}px)")

    for folder, px in ADAPTIVE_DENSITIES.items():
        out = ANDROID_RES / folder / "ic_launcher_foreground.png"
        adaptive_foreground(px).save(out)
        print(f"wrote {out.relative_to(REPO)} ({px}px)")

    anydpi = ANDROID_RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")
    print(f"wrote {anydpi.relative_to(REPO) / 'ic_launcher.xml'}")

    (ANDROID_RES / "values" / "colors.xml").write_text(COLORS_XML, encoding="utf-8")
    print(f"wrote {(ANDROID_RES / 'values' / 'colors.xml').relative_to(REPO)}")

    for (tag, scale, px) in IOS_SIZES:
        out = IOS_APPICON / f"Icon-App-{tag}@{scale}x.png"
        ios_icon(px).save(out, format="PNG")
        print(f"wrote {out.relative_to(REPO)} ({px}px)")


if __name__ == "__main__":
    main()
