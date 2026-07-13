"""Compose the Daftar logomark: a fused D / د monogram, white on Teal.

The two glyphs are drawn in white onto one layer, so their union reads as a
single fused silhouette (see docs/design-system.md — Brand). Outputs:

  logo_icon.png        1024²  Teal rounded square + centred white mark (iOS/web/legacy)
  logo_foreground.png  1024²  transparent, white mark within the adaptive safe zone
  splash_logo.png      transparent, white mark over the wordmark (native splash)
"""
"""Run: python tool/make_logo.py   (needs Pillow, arabic-reshaper, python-bidi)
Then regenerate native assets: dart run flutter_launcher_icons
                               dart run flutter_native_splash:create"""
import os
import sys
import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont


def shape_ar(text):
    """Reshape + reorder Arabic so Pillow draws it connected and RTL-correct."""
    return get_display(arabic_reshaper.reshape(text))

TEAL = (0x14, 0x74, 0x6F, 0xFF)
WHITE = (0xFF, 0xFF, 0xFF, 0xFF)
_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(_ROOT, "assets", "fonts")
OUT = os.path.join(_ROOT, "assets", "branding")

# Supersample everything 4x then downscale for crisp anti-aliased edges.
SS = 4

# --- tunables (iterate here) -------------------------------------------------
D_SIZE = 620          # Latin D cap height driver
DAL_SIZE = 560        # Arabic dal driver
DAL_DX = 250          # dal horizontal offset from centre (+ = right)
DAL_DY = -10          # dal vertical offset (+ = down)
D_DX = -70            # D horizontal offset from centre
# ----------------------------------------------------------------------------


def _font(name, px):
    return ImageFont.truetype(f"{FONTS}/{name}", px * SS)


def build_mark():
    """White fused D/د on a transparent square, tightly cropped."""
    pad = 200 * SS
    canvas = 1400 * SS
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = canvas // 2

    d_font = _font("IBMPlexSans-Bold.ttf", D_SIZE)
    dal_font = _font("IBMPlexSansArabic-Bold.ttf", DAL_SIZE)

    # Draw both glyphs in white at the centre; their union is the mark.
    d.text((cx + D_DX * SS, cy), "D", font=d_font, fill=WHITE, anchor="mm")
    d.text((cx + DAL_DX * SS, cy + DAL_DY * SS), "د",
           font=dal_font, fill=WHITE, anchor="mm")

    bbox = img.getbbox()
    mark = img.crop(bbox)
    # Pad to a square so it centres cleanly on the tile.
    side = max(mark.size) + pad
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(mark, ((side - mark.width) // 2, (side - mark.height) // 2), mark)
    return square


def rounded_tile(size, radius_frac=0.22):
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    r = int(size * radius_frac)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=TEAL)
    return tile


def fit_mark(mark, target, frac):
    """Scale mark so its side is `frac` of a `target`-px canvas, centred."""
    side = int(target * frac)
    scaled = mark.resize((side, side), Image.LANCZOS)
    out = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    off = (target - side) // 2
    out.paste(scaled, (off, off), scaled)
    return out


def main():
    mark = build_mark()

    # 1) Full icon: mark on the Teal rounded tile (~62% of the canvas).
    tile = rounded_tile(1024)
    icon = tile.copy()
    m = fit_mark(mark, 1024, 0.62)
    icon.alpha_composite(m)
    icon.save(f"{OUT}/logo_icon.png")

    # 2) Android-12 splash icon: transparent, mark kept small (~56%) so it sits
    #    comfortably inside the circular splash mask.
    fg = fit_mark(mark, 1024, 0.56)
    fg.save(f"{OUT}/logo_foreground.png")

    # 2b) Adaptive-icon foreground: the generated adaptive XML already insets the
    #     drawable 16%, so the art itself fills more of the canvas (~0.90) to end
    #     up ~0.60 of the masked launcher icon.
    afg = fit_mark(mark, 1024, 0.90)
    afg.save(f"{OUT}/logo_adaptive_fg.png")

    # 3) Splash: white mark above the wordmark, on transparent (Teal comes from
    #    native_splash's colour). Rendered wide so the wordmark fits.
    W, H = 1200, 1400
    splash = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m2 = mark.resize((620, 620), Image.LANCZOS)
    splash.paste(m2, ((W - 620) // 2, 240), m2)
    sd = ImageDraw.Draw(splash)
    wm = ImageFont.truetype(f"{FONTS}/IBMPlexSans-SemiBold.ttf", 150)
    ar = ImageFont.truetype(f"{FONTS}/IBMPlexSansArabic-SemiBold.ttf", 150)
    sd.text((W // 2, 990), "Daftar", font=wm, fill=WHITE, anchor="mm")
    sd.text((W // 2, 1180), shape_ar("دفتر"), font=ar, fill=WHITE, anchor="mm")
    splash.save(f"{OUT}/splash_logo.png")

    print("wrote logo_icon.png, logo_foreground.png, logo_adaptive_fg.png, "
          "splash_logo.png")


if __name__ == "__main__":
    sys.exit(main())
