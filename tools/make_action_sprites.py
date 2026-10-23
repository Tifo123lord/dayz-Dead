"""Builds the 'free arm' sprites used by the action animations.

For every hero the idle walk frame is split into
  * <hero>_body.png : idle frame with the near (front) forearm + hand removed
  * <hero>_hand.png : the gloved hand only (wrist at the top centre)
Run from the project root:  python3 tools/make_action_sprites.py
"""
from PIL import Image

HEROES = {
    # sheet, cut x per row range, hand box, outline colour
    'arash': dict(sheet='assets/images/survivor_walk.png', cut_x=121,
                  rows=(124, 178), hand=(122, 157, 143, 177)),
    'donald': dict(sheet='assets/characters/donald/walk.png', cut_x=128,
                   rows=(132, 186), hand=(130, 154, 151, 185)),
}
IDLE = 7
CELL_W, CELL_H = 168, 300

for name, c in HEROES.items():
    sheet = Image.open(c['sheet']).convert('RGBA')
    idle = sheet.crop((IDLE * CELL_W, 0, IDLE * CELL_W + CELL_W, CELL_H))
    hand = idle.crop(c['hand'])
    body = idle.copy()
    px = body.load()
    y0, y1 = c['rows']
    cx = c['cut_x']
    for y in range(y0, y1):
        # Feather the cut over the first rows so the shoulder blends.
        start = cx + max(0, (y0 + 6 - y))
        for x in range(start, CELL_W):
            px[x, y] = (0, 0, 0, 0)
        # Dark outline on the new edge.
        if px[start - 1, y][3] > 0:
            r, g, b, a = px[start - 1, y]
            px[start - 1, y] = (r // 3, g // 3, b // 3, 255)
    body.save(f'assets/characters/{name}_body.png')
    hand.save(f'assets/characters/{name}_hand.png')
    print(name, 'hand', hand.size)
