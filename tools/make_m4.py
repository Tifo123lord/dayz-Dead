"""Procedural 2D pixel-art M4A1 carbine (no photos, every pixel is drawn here).

The rifle is built from flat shapes on a material map, then shaded
(automatic rim light / under-shadow + hand-placed details), textured and
outlined, so it matches the hand-painted AK-47 sprite.  The canvas is the
same size as the AK sprite (360 x 101) and the pistol grip, handguard and
muzzle sit at the same spots, so every carry / aim geometry in the game is
shared with the AK.

Run from the project root:  python3 tools/make_m4.py
Outputs  assets/images/m4.png  and  assets/skins/m4_<skin>.png
"""
import random

import numpy as np
from PIL import Image, ImageDraw

W, H = 360, 101

# Materials
NONE, METAL, POLY, DARK, BRIGHT, STEEL = 0, 1, 2, 3, 4, 5

mat = Image.new('L', (W, H), NONE)
shade = Image.new('L', (W, H), 128)  # 128 = neutral, >128 light, <128 dark
dm = ImageDraw.Draw(mat)
ds = ImageDraw.Draw(shade)


def poly(points, m):
    dm.polygon(points, fill=m)


def rect(x0, y0, x1, y1, m):
    dm.rectangle([x0, y0, x1, y1], fill=m)


def sh(points_or_box, v, kind='rect'):
    if kind == 'rect':
        ds.rectangle(points_or_box, fill=v)
    elif kind == 'line':
        ds.line(points_or_box, fill=v, width=1)
    else:
        ds.polygon(points_or_box, fill=v)


# ---------------------------------------------------------------------------
# Silhouette
# ---------------------------------------------------------------------------

# Buffer tube (receiver extension) running into the collapsible stock.
rect(40, 19, 100, 29, METAL)

# CAR-15 / M4 collapsible stock (polymer).
poly([(4, 13), (14, 12), (64, 18), (66, 30), (44, 38), (28, 52),
      (14, 63), (4, 64)], POLY)
# Butt pad (rubber, darker).
rect(2, 12, 9, 65, DARK)
# Sling slot / lightening cut.
poly([(18, 44), (34, 33), (40, 35), (24, 49)], NONE)
# Stock adjustment lever under the tube.
poly([(46, 30), (60, 30), (58, 35), (48, 35)], METAL)

# Upper receiver (flat-top).
poly([(92, 15), (206, 15), (206, 33), (92, 33)], METAL)
# Picatinny rail on top of the upper receiver.
rect(96, 9, 204, 15, METAL)
# Charging handle (rear, latch sticking out).
rect(88, 15, 97, 21, METAL)
poly([(86, 14), (92, 14), (92, 18), (86, 18)], METAL)
# Brass deflector bump.
poly([(166, 32), (178, 32), (176, 38), (168, 38)], METAL)
# Forward assist.
rect(180, 26, 190, 34, METAL)

# Lower receiver.
poly([(96, 33), (200, 33), (198, 46), (186, 48), (186, 58), (150, 58),
      (148, 48), (126, 48), (100, 46)], METAL)
# Buffer-tube castle nut / receiver end plate.
rect(96, 18, 102, 32, METAL)

# Pistol grip (A2, polymer, angled back) with finger ridge.
poly([(104, 44), (128, 44), (126, 50), (119, 84), (113, 87), (99, 86),
      (96, 82), (103, 56)], POLY)
# Trigger guard.
poly([(126, 47), (152, 47), (152, 50), (148, 60), (128, 60), (128, 57),
      (146, 57), (147, 50), (126, 50)], METAL)
# Trigger.
poly([(134, 48), (138, 48), (137, 55), (133, 54)], DARK)

# 30-round STANAG magazine (gently curved).
poly([(152, 48), (184, 48), (186, 62), (190, 80), (195, 96),
      (165, 99), (160, 82), (156, 64)], METAL)
# Base plate.
poly([(163, 96), (197, 93), (198, 99), (165, 100)], DARK)

# Delta ring + handguard cap.
rect(204, 10, 211, 38, METAL)
# M4 two-piece ribbed handguard (polymer).
poly([(211, 12), (288, 15), (290, 18), (290, 32), (288, 35), (211, 37)],
     POLY)
# Handguard cap at the front.
rect(287, 15, 292, 35, METAL)

# Barrel.
rect(292, 20, 342, 27, STEEL)
# Front sight base (A-frame) + bayonet lug.
poly([(300, 18), (316, 18), (316, 31), (300, 31)], METAL)
poly([(302, 18), (306, 3), (310, 3), (314, 18)], METAL)
rect(305, 31, 312, 36, METAL)
# A2 birdcage flash hider.
rect(342, 18, 358, 29, STEEL)

# Flip-up rear sight (BUIS) on the rail.
poly([(104, 9), (106, 2), (114, 2), (116, 9)], METAL)

# ---------------------------------------------------------------------------
# Automatic lighting: top rim light, bottom shadow (per material shape).
# ---------------------------------------------------------------------------
M = np.array(mat)
S = np.array(shade).astype(int)
filled = M > 0


def edge(dy, dx):
    sh_ = np.roll(np.roll(M, dy, 0), dx, 1)
    return filled & (sh_ != M)


top = edge(1, 0)
top2 = filled & np.roll(top, 1, 0) & ~top
bottom = edge(-1, 0)
bottom2 = filled & np.roll(bottom, -1, 0) & ~bottom
S[top] += 60
S[top2] += 28
S[bottom] -= 45
S[bottom2] -= 20
shade = Image.fromarray(np.clip(S, 0, 255).astype(np.uint8))
ds = ImageDraw.Draw(shade)

# ---------------------------------------------------------------------------
# Hand-placed details
# ---------------------------------------------------------------------------
# Rail teeth (slots every 4 px).
for x in range(98, 204, 4):
    sh([x, 9, x + 1, 12], 60)
    sh([x + 2, 9, x + 3, 9], 205)
# Rear sight aperture.
sh([108, 4, 111, 6], 30)
# Charging handle seam.
sh([(88, 21), (101, 21)], 70, 'line')
# Upper / lower receiver split line.
sh([(100, 33), (200, 33)], 60, 'line')
sh([(100, 34), (198, 34)], 160, 'line')
# Ejection port + dust cover (open-port recess with hinge rod).
sh([134, 20, 164, 28], 92)
sh([134, 20, 164, 20], 55)
sh([135, 27, 164, 27], 165)
sh([(134, 29), (164, 29)], 70, 'line')
# Forward assist ribs.
for x in (182, 185, 188):
    sh([x, 27, x, 33], 80)
# Receiver pins (takedown + pivot).
for (x, y) in ((106, 39), (187, 38), (140, 41)):
    sh([x, y, x + 2, y + 2], 60)
    sh([x, y, x + 1, y], 200)
# Fire selector (SAFE / SEMI / BURST) lever.
sh([(112, 37), (122, 34)], 200, 'line')
sh([(112, 38), (122, 35)], 60, 'line')
# Magazine release button.
sh([152, 38, 156, 42], 175)
# Magazine ribs + curve shading.
for i, y in enumerate(range(54, 94, 8)):
    x0 = 156 + i * 2
    sh([(x0 + 2, y), (x0 + 30, y - 1)], 92, 'line')
    sh([(x0 + 2, y + 1), (x0 + 30, y)], 160, 'line')
sh([(158, 50), (167, 97)], 165, 'line')
# Pistol-grip finger grooves + texture.
for y in range(52, 84, 6):
    sh([(102, y), (122, y)], 92, 'line')
# Stock ribs / position stamps on the tube.
for x in range(66, 98, 6):
    sh([x, 20, x + 1, 28], 95)
sh([(10, 13), (62, 19)], 180, 'line')
# Butt pad grooves.
for y in range(16, 62, 5):
    sh([3, y, 8, y], 85)
# Handguard: two rows of vent holes + longitudinal ribs.
for x in range(216, 284, 7):
    sh([x, 18, x + 3, 21], 45)
    sh([x, 28, x + 3, 31], 45)
    sh([x, 22, x + 3, 22], 175)
sh([(212, 25), (286, 25)], 95, 'line')
# Delta ring bands.
for x in (205, 209):
    sh([x, 11, x, 37], 175)
# Barrel highlight / shadow.
sh([(292, 21), (341, 21)], 205, 'line')
sh([(292, 26), (341, 26)], 70, 'line')
# Front sight post window + pin.
sh([306, 7, 310, 15], 40)
sh([(306, 24), (309, 24)], 200, 'line')
# Flash hider slots.
for x in (345, 349, 353):
    sh([x, 19, x + 1, 23], 35)
sh([342, 27, 358, 28], 70)

S = np.array(shade).astype(int)

# ---------------------------------------------------------------------------
# Colouring
# ---------------------------------------------------------------------------


def camo(seed, colors, scale=7, cells=None):
    """Blobby camo pattern: returns an (H, W, 3) array."""
    rnd = random.Random(seed)
    img = Image.new('RGB', (W, H), colors[0])
    d = ImageDraw.Draw(img)
    for _ in range(cells or 110):
        c = rnd.choice(colors[1:])
        x, y = rnd.randrange(-10, W), rnd.randrange(-10, H)
        r = rnd.randrange(scale // 2, scale * 2)
        pts = []
        for k in range(7):
            a = k / 7 * 6.283
            rr = r * (0.6 + rnd.random() * 0.7)
            pts.append((x + np.cos(a) * rr * 1.6, y + np.sin(a) * rr))
        d.polygon(pts, fill=c)
    return np.array(img).astype(int)


def digital(seed, colors, px=3):
    rnd = random.Random(seed)
    arr = np.zeros((H, W, 3), int)
    for y in range(0, H, px):
        for x in range(0, W, px):
            c = colors[min(len(colors) - 1, int(rnd.random() ** 1.3 *
                                                len(colors)))]
            arr[y:y + px, x:x + px] = c
    return arr


SKINS = {
    # id: material -> base colour (or pattern array)
    'stock': {
        METAL: (46, 48, 50), POLY: (38, 39, 40), DARK: (22, 22, 23),
        STEEL: (58, 60, 63), 'outline': (10, 10, 12),
    },
    'tan': {
        METAL: (52, 50, 46), POLY: (150, 122, 84), DARK: (30, 28, 25),
        STEEL: (60, 60, 62), 'outline': (16, 13, 10),
    },
    'woodland': {
        METAL: 'camo', POLY: 'camo', DARK: (26, 26, 22), STEEL: (56, 58, 58),
        'outline': (12, 12, 10),
        'pattern': camo(7, [(74, 82, 52), (40, 48, 30), (96, 78, 50),
                            (24, 26, 20)]),
    },
    'urban': {
        METAL: 'camo', POLY: 'camo', DARK: (30, 32, 36), STEEL: (66, 70, 76),
        'outline': (12, 13, 16),
        'pattern': digital(11, [(110, 116, 122), (78, 84, 92), (150, 156, 160),
                                (44, 48, 54)]),
    },
    'gold': {
        METAL: (196, 150, 52), POLY: (34, 26, 20), DARK: (60, 40, 14),
        STEEL: (214, 172, 70), 'outline': (40, 24, 6),
    },
}


def render(skin):
    pal = SKINS[skin]
    out = np.zeros((H, W, 4), int)
    rnd = np.random.default_rng(5)
    noise = rnd.integers(-7, 8, (H, W))
    for m in (METAL, POLY, DARK, STEEL, BRIGHT):
        sel = M == m
        if not sel.any():
            continue
        base = pal.get(m, pal[METAL])
        if base == 'camo':
            col = pal['pattern'].copy()
        else:
            col = np.zeros((H, W, 3), int)
            col[:] = base
        k = (S - 128) / 128.0  # -1..1
        light = np.where(k[..., None] > 0, col + (255 - col) * k[..., None] * 0.55,
                         col * (1 + k[..., None] * 0.85))
        # Polymer gets a finer grain than metal.
        grain = noise * (1.0 if m == POLY else 0.6)
        light = light + grain[..., None]
        out[sel, :3] = np.clip(light[sel], 0, 255)
        out[sel, 3] = 255
    # 2 px dark outline around the silhouette.
    a = out[..., 3] > 0
    ring = np.zeros_like(a)
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            if abs(dy) + abs(dx) > 3:
                continue
            ring |= np.roll(np.roll(a, dy, 0), dx, 1)
    ring &= ~a
    out[ring, :3] = pal['outline']
    out[ring, 3] = 255
    # Inner 1 px contour where materials meet (reads as panel seams).
    seam = a & (np.roll(M, -1, 1) != M) & (np.roll(M, -1, 1) > 0)
    out[seam, :3] = (out[seam, :3] * 0.55).astype(int)
    return Image.fromarray(out.astype(np.uint8), 'RGBA')


if __name__ == '__main__':
    render('stock').save('assets/images/m4.png')
    for s in ('tan', 'woodland', 'urban', 'gold'):
        render(s).save(f'assets/skins/m4_{s}.png')
    print('M4 sprites written')
