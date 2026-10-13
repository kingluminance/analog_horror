"""Generates Ellikonti's hand-painted low-res body textures and face layers.

Run from anywhere:  python entities/ellikonti/model/make_textures.py
(Pillow only, no Blender needed.) Output:
  entities/ellikonti/textures/<part>.png   64x64 painted swatches, one per body part
  entities/ellikonti/faces/{eyes,mouth,extra}_<name>.png   128x128 RGBA face layers

Look target is PS1-era character textures: tiny, nearest-filtered, painted
top-to-bottom gradient with visible brush blotches. The blotches are the
translucent rectangular strokes from the user's colour sketch (they painted
the colours with a chunky square brush), so the 3D version keeps that mark.

Body UVs are a straight front projection per part (see build_ellikonti.py),
so "top of the texture" is always "top of the part" -- the gradient reads
as light from above on every piece.

Face layers are drawn big and downsampled with a hard alpha threshold, so the
lines stay crisp pixels instead of blurry antialiasing (same as the reference
faces: black drawn lines on a flat face). The face is split into three layers
(eyes / mouth / extra) so expressions can mix -- see ellikonti.gd EXPRESSIONS.
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TEX_DIR = os.path.join(ROOT, "textures")
FACE_DIR = os.path.join(ROOT, "faces")

# Colours picked from the user's sketch.
PARTS = {
    "hat": ((0x9A, 0x2C, 0x96), (0x6A, 0x12, 0x6C)),
    "head": ((0x92, 0xAA, 0xE8), (0x66, 0x7E, 0xC4)),
    "torso": ((0x92, 0xC8, 0x8C), (0x48, 0x96, 0x48)),
    "hand": ((0x8C, 0xC0, 0x86), (0x44, 0x8C, 0x44)),
    "knee": ((0x9A, 0x40, 0xFF), (0x6A, 0x14, 0xD8)),
    # The long diagonal sliver crosses from the green zone into the purple
    # zone in the sketch, so it fades green -> violet top to bottom.
    "leg": ((0x6E, 0xAE, 0x6C), (0x7A, 0x1C, 0xEC)),
    "star": ((0xF2, 0xEE, 0xB0), (0xC8, 0xC2, 0x78)),
    "bell": ((0xE6, 0xD2, 0x8A), (0xA8, 0x8A, 0x40)),
    "ink": ((0x22, 0x1A, 0x24), (0x10, 0x0C, 0x12)),
}

SIZE = 64

# Fixed per-part seeds so removing/adding a part never reshuffles the brush
# blotches on the others (the hair part used to sit at 1001).
SEEDS = {"hat": 1000, "head": 1002, "torso": 1003, "hand": 1004, "knee": 1005,
         "leg": 1006, "star": 1007, "bell": 1008, "ink": 1009}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def clamp8(v):
    return max(0, min(255, int(v)))


# Parts painted as a clean gradient (no square-brush strokes) -- the face is
# drawn on the head, so blotches there read as dirt/bruises.
NO_STROKES = {"head"}


def painted_swatch(top, bottom, seed, strokes=True):
    rng = random.Random(seed)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        c = lerp(top, bottom, y / (SIZE - 1))
        for x in range(SIZE):
            px[x, y] = c

    # Translucent square-brush strokes, mostly horizontal like the sketch.
    over = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for _ in range(14 if strokes else 0):
        w = rng.randint(14, 40)
        h = rng.randint(4, 11)
        x0 = rng.randint(-8, SIZE - 8)
        y0 = rng.randint(-4, SIZE - 4)
        base = lerp(top, bottom, max(0.0, min(1.0, (y0 + h / 2) / SIZE)))
        k = rng.uniform(0.82, 1.18)
        col = tuple(clamp8(v * k) for v in base)
        d.rectangle([x0, y0, x0 + w, y0 + h], fill=col + (rng.randint(50, 110),))
    img = Image.alpha_composite(img.convert("RGBA"), over).convert("RGB")

    # Per-pixel grain so it reads as a low-res paint texture, not a gradient.
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            n = rng.randint(-7, 7)
            r, g, b = px[x, y]
            px[x, y] = (clamp8(r + n), clamp8(g + n), clamp8(b + n))
    return img


# ---------------------------------------------------------------- face layers
FS = 128  # final face texture size
BIG = FS * 4  # drawn at 4x, downsampled with a hard alpha cut
INK = (24, 16, 28, 255)
WHITE = (238, 236, 226, 255)


def new_layer():
    img = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def P(u, v):
    """Face-UV (0..1) -> big-canvas pixel."""
    return (u * BIG, v * BIG)


def finish(img):
    small = img.resize((FS, FS), Image.LANCZOS)
    px = small.load()
    for y in range(FS):
        for x in range(FS):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return small


# Eye positions follow the sketch: low on the face and tilted (right eye
# higher), so even the neutral face looks like it is glancing down-left.
EYE_L = (0.33, 0.60)
EYE_R = (0.63, 0.51)
MOUTH = (0.50, 0.68)
EYE_TILT = math.atan2(EYE_R[1] - EYE_L[1], EYE_R[0] - EYE_L[0])


def ellipse(d, c, rx, ry, **kw):
    x, y = P(*c)
    d.ellipse([x - rx * BIG, y - ry * BIG, x + rx * BIG, y + ry * BIG], **kw)


def rot(dx, dy):
    ca, sa = math.cos(EYE_TILT), math.sin(EYE_TILT)
    return dx * ca - dy * sa, dx * sa + dy * ca


def tilted_line(d, c, pts, width):
    cx, cy = c
    out = []
    for dx, dy in pts:
        rx, ry = rot(dx, dy)
        out.append(P(cx + rx, cy + ry))
    d.line(out, fill=INK, width=width, joint="curve")


def eyes_default():
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        ellipse(d, c, 0.045, 0.056, fill=INK)
    return img


def eyes_panic():
    # Wide white eyes with pin-prick pupils looking off to the side.
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        ellipse(d, c, 0.09, 0.10, fill=WHITE, outline=INK, width=int(0.018 * BIG))
        ellipse(d, (c[0] - 0.026, c[1] + 0.014), 0.018, 0.02, fill=INK)
    return img


def eyes_halflid():
    # Reference-style heavy upper lid over the dot eye: tired / resigned.
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        ellipse(d, (c[0], c[1] + 0.012), 0.030, 0.030, fill=INK)
        tilted_line(d, c, [(-0.07, 0.0), (-0.03, -0.012), (0.03, -0.012), (0.075, 0.004)],
                    int(0.022 * BIG))
    return img


def eyes_closed():
    # Squeezed shut ">  <".
    img, d = new_layer()
    w = int(0.02 * BIG)
    tilted_line(d, EYE_L, [(-0.055, -0.04), (0.035, 0.0), (-0.055, 0.04)], w)
    tilted_line(d, EYE_R, [(0.055, -0.04), (-0.035, 0.0), (0.055, 0.04)], w)
    return img


def eyes_teary():
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        ellipse(d, c, 0.045, 0.052, fill=INK)
        ellipse(d, (c[0] + 0.014, c[1] - 0.016), 0.013, 0.014, fill=WHITE)
        # wobbly lower lid of welling tears
        tilted_line(d, (c[0], c[1] + 0.062),
                    [(-0.06, 0.0), (-0.03, 0.012), (0.0, 0.0), (0.03, 0.012), (0.06, 0.0)],
                    int(0.012 * BIG))
    return img


def eyes_diverge():
    # Contract cutscene: round staring eyes, each pupil looking somewhere
    # different (left one up-left, right one down-right) -- nobody home.
    img, d = new_layer()
    for c, (dx, dy) in ((EYE_L, (-0.03, -0.035)), (EYE_R, (0.032, 0.03))):
        ellipse(d, c, 0.085, 0.09, fill=WHITE, outline=INK, width=int(0.016 * BIG))
        ellipse(d, (c[0] + dx, c[1] + dy), 0.026, 0.028, fill=INK)
    return img


def mouth_default():
    # Small open beak-triangle from the sketch.
    img, d = new_layer()
    x, y = MOUTH
    tri = [P(x - 0.055, y - 0.032), P(x + 0.05, y - 0.04), P(x - 0.015, y + 0.05)]
    d.polygon(tri, fill=(70, 40, 80, 255))
    d.line(tri + [tri[0]], fill=INK, width=int(0.016 * BIG), joint="curve")
    return img


def mouth_open():
    img, d = new_layer()
    x, y = MOUTH
    tri = [P(x - 0.065, y - 0.035), P(x + 0.06, y - 0.045), P(x - 0.01, y + 0.07)]
    d.polygon(tri, fill=(60, 20, 50, 255))
    d.line(tri + [tri[0]], fill=INK, width=int(0.018 * BIG), joint="curve")
    return img


def mouth_wavy():
    img, d = new_layer()
    x, y = MOUTH
    # jagged clenched line, sharp enough that it can't read as a smile
    pts = [P(x - 0.08 + i * 0.02, y + (0.022 if i % 2 else -0.022)) for i in range(9)]
    d.line(pts, fill=INK, width=int(0.016 * BIG), joint="curve")
    return img


def mouth_small():
    img, d = new_layer()
    ellipse(d, MOUTH, 0.024, 0.03, fill=(60, 20, 50, 255), outline=INK, width=int(0.012 * BIG))
    return img


def mouth_none():
    # Blank mouth layer: the cutscene swaps in a separate 3D mouth that can
    # actually stretch open (contract_cutscene/), so the painted one hides.
    return new_layer()[0]


def extra_none():
    return new_layer()[0]


def drop(d, x, y, s):
    d.polygon([P(x, y - 1.6 * s), P(x - s, y), P(x + s, y)], fill=(200, 230, 250, 255))
    ellipse(d, (x, y), s, s, fill=(200, 230, 250, 255), outline=INK, width=int(0.008 * BIG))


def extra_sweat():
    img, d = new_layer()
    drop(d, 0.80, 0.40, 0.035)
    drop(d, 0.86, 0.55, 0.025)
    drop(d, 0.17, 0.47, 0.028)
    # anxiety lines on the forehead side
    for i in range(3):
        u = 0.70 + i * 0.045
        d.line([P(u, 0.36), P(u - 0.01, 0.43)], fill=INK, width=int(0.010 * BIG))
    return img


def extra_tears():
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        x, y = c
        d.line([P(x, y + 0.06), P(x - 0.01, y + 0.16), P(x + 0.005, y + 0.26)],
               fill=(200, 230, 250, 255), width=int(0.030 * BIG), joint="curve")
    return img


def extra_blush():
    img, d = new_layer()
    for c in (EYE_L, EYE_R):
        x, y = c
        for i in range(3):
            u = x - 0.04 + i * 0.03
            d.line([P(u + 0.01, y + 0.085), P(u - 0.01, y + 0.115)],
                   fill=(150, 60, 120, 255), width=int(0.011 * BIG))
    return img


FACES = {
    "eyes_default": eyes_default,
    "eyes_panic": eyes_panic,
    "eyes_halflid": eyes_halflid,
    "eyes_closed": eyes_closed,
    "eyes_teary": eyes_teary,
    "eyes_diverge": eyes_diverge,
    "mouth_default": mouth_default,
    "mouth_open": mouth_open,
    "mouth_wavy": mouth_wavy,
    "mouth_small": mouth_small,
    "mouth_none": mouth_none,
    "extra_none": extra_none,
    "extra_sweat": extra_sweat,
    "extra_tears": extra_tears,
    "extra_blush": extra_blush,
}


STAR_DIR = os.path.join(ROOT, "contract_cutscene")
STARS = {"star_pink": (0xFF, 0x2A, 0xD4), "star_green": (0x7C, 0xFF, 0x2E)}


def star_sprite(colour):
    """Chunky 5-point star like the ones in the user's storyboard, black edge."""
    big = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        r = 120 if i % 2 == 0 else 52
        pts.append((128 + math.cos(a) * r, 132 + math.sin(a) * r))
    d.polygon(pts, fill=colour + (255,), outline=INK, width=14)
    small = big.resize((32, 32), Image.LANCZOS)
    px = small.load()
    for y in range(32):
        for x in range(32):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    return small


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    os.makedirs(FACE_DIR, exist_ok=True)
    for name, (top, bottom) in PARTS.items():
        painted_swatch(top, bottom, seed=SEEDS[name], strokes=name not in NO_STROKES).save(os.path.join(TEX_DIR, name + ".png"))
    for name, fn in FACES.items():
        finish(fn()).save(os.path.join(FACE_DIR, name + ".png"))
    os.makedirs(STAR_DIR, exist_ok=True)
    for name, colour in STARS.items():
        star_sprite(colour).save(os.path.join(STAR_DIR, name + ".png"))
    print("textures:", len(PARTS), "faces:", len(FACES), "stars:", len(STARS))


if __name__ == "__main__":
    main()
