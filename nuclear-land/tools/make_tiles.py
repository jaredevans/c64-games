"""Tile art -> gen/tiles.bin (glyphs from TILE_FIRST up), gen/tilecolors.bin (256), gen/tiles.inc.

Codes below TILE_FIRST are the C64 ROM font (copied into the charset at runtime, never committed).
Passable tiles (and the UI glyphs, which never appear in a map) get codes TILE_FIRST..BLOCK_BASE-1;
impassable tiles BLOCK_BASE and up. Each tile has one colour (hi-res characters on black)."""
from pathlib import Path

GEN = Path(__file__).resolve().parent.parent / 'gen'
TILE_FIRST = 64
BLOCK_BASE = 128
FONT_COLOR = 1          # white
(BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW, ORANGE, BROWN, LRED, DGREY, GREY, LGREEN, LBLUE,
 LGREY) = range(16)

# name: (colour, 8 rows of '#'/'.')
PASSABLE = {
    'GROUND0': (BROWN, "........ ...#.... ........ ......#. .#...... ........ ....#... ........"),
    'GROUND1': (BROWN, "........ ........ .....#.. ........ ........ ..#..... ........ ......#."),
    'GROUND2': (BROWN, "....#... ........ ........ .#...... ........ .....#.. ........ ........"),
    'ROAD':    (GREY,  "#.#.#.#. .#.#.#.# #.#.#.#. .#.#.#.# #.#.#.#. .#.#.#.# #.#.#.#. .#.#.#.#"),
    'ROAD_LANE_H': (GREY, "#.#.#.#. .#.#.#.# #.#.#.#. ........ .######. ........ #.#.#.#. .#.#.#.#"),
    'ROAD_LANE_V': (GREY, "#.#...#. .#.....# #.#.#.#. .#.#...# #.#.#.#. .#.#...# #.#.#.#. .#.....#"),
    'ROAD_CRACK':  (GREY, "#.#.#.#. .#.#...# #.#...#. .#...#.# #...#.#. .#.#.#.# #.#.#.#. .#.#.#.#"),
    'HOT0':    (LGREEN, "..#..... .###..#. ..#..### ......#. ...#.... ..###... ...#..#. ........"),
    'HOT1':    (LGREEN, "......#. .#...### ###...#. .#...... ....#... ...###.# ....#.## .......#"),
}
UI = {                  # exported as G_<NAME>; colour comes from the HUD, not the map
    'BAR0': "........ ........ ........ ........ ........ ........ #.#.#.#. ........",
    'BAR1': "........ ........ ##...... ##...... ##...... ##...... ##.#.#.# ........",
    'BAR2': "........ ........ ####.... ####.... ####.... ####.... ####.#.# ........",
    'BAR3': "........ ........ ######.. ######.. ######.. ######.. ####.#.# ........",
    'BAR4': "........ ........ #######. #######. #######. #######. #######. ........",
    'METER_OFF': "........ ........ ........ ...##... ...##... ........ ........ ........",
    'METER_ON':  "........ .######. .######. .######. .######. .######. .######. ........",
}
BLOCKED = {
    'WALL':    (LGREY, "###.#### ###.#### ........ #######. #######. ........ ###.#### ###.####"),
    'RUBBLE':  (GREY,  "........ ..##.... .####.#. .#####.. ........ .....##. #...#### ##..####"),
    'CONCRETE': (GREY, "######## #...#..# #...#..# ######## ..#...#. ..#...#. ####.#.# ........"),
    'WINDOW':  (LGREY, "######## #......# #.#..#.# #..##..# #.#....# #...#..# #......# ########"),
    'DOOR':    (BROWN, "..####.. .#....#. .#....#. .#....#. .#..#.#. .#....#. .#....#. .#....#."),
    'ROOF':    (GREY,  "#..#..#. #..#..#. #..#..#. #..#..#. #..#..#. #..#..#. #..#..#. #..#..#."),
    'ROOF_EDGE': (GREY, "#..#..#. #..#..#. #..#..#. #..#..#. #..#..#. ######## ####.#.# ........"),
    'FENCE_H': (LGREY, "######## .#...#.. #.#.#.#. ...#...# ..#.#.#. .#...#.. #.#.#.#. ...#...#"),
    'FENCE_V': (LGREY, "#.#...#. #..#.#.. #...#... #..#.#.. #.#...#. ##.....# #.#...#. #..#.#.."),
    'POST':    (LGREY, "..####.. ...##... ...##... ...##... ...##... ...##... ...##... ..####.."),
    'GATE':    (ORANGE, "######## #.#.#.#. #.#.#.#. #.#.#.#. #.#.#.#. #.#.#.#. #.#.#.#. ########"),
    'SIGN':    (YELLOW, "...##... ..#..#.. ..#..#.. .#.##.#. .#.##.#. #......# #..##..# ########"),
    'BARREL':  (ORANGE, ".######. #......# .######. .######. .######. .######. #......# .######."),
    'GLASS':   (CYAN,  "######## #..#...# #.#....# ##.....# ######## #...#..# #..#...# ########"),
    'PLANTS':  (GREEN, "..#..#.. .###.##. #.#.##.# .###.#.. ..#.###. .#.#.#.. ...#.#.. ..#####."),
    'CAR_L':   (RED,   "........ ...##### ..#....# .#.....# ######## #.##.### #.##.### .##....."),
    'CAR_R':   (RED,   "........ ####.... #...#... #....#.. #######. ###.##.# ###.##.# .....##."),
    'PUMP':    (LBLUE, "..###... ...#.... .#####.. .#...#.. .#...#.# .#...### .#####.. ########"),
    'STALL':   (BROWN, "######## #.#.#.#. ######## #......# #......# ######## #......# #......#"),
    'TENT':    (ORANGE, "...##... ..#..#.. ..#..#.. .#....#. .#.##.#. #..##..# #..##..# ########"),
    'CART':    (BROWN, "........ ######## #......# ######## .#....#. #.#..#.# .#....#. ........"),
}
DOME_COLOR = WHITE
DOME_W, DOME_H = 6, 4   # cells


def dome_art():
    """48x32 pixel reactor dome: a ribbed half-dome on a banded concrete base, as '#'/'.' rows."""
    w, h = DOME_W * 8, DOME_H * 8
    cx, r = (w - 1) / 2, 22.5
    rows = []
    for y in range(h):
        row = []
        for x in range(w):
            on = False
            if y < 23:                                   # dome: outline + ribs + latitude bands
                d = ((x - cx) ** 2 + ((y - 23) * 1.0) ** 2) ** 0.5
                inside = d <= r
                if inside and d > r - 1.6:
                    on = True
                elif inside and y in (8, 15, 20):
                    on = (x % 2 == 0)
                elif inside and abs(x - cx) < 0.6 + (23 - y) * 0 and y > 1:
                    on = True
                elif inside and x in (12, 35) and y > 6:
                    on = True
                if y == 0 and abs(x - cx) <= 3:          # vent on top
                    on = True
            elif y in (23, 24):
                on = 1 <= x <= w - 2
            elif y == h - 1:
                on = True
            else:                                        # base wall with hatch-like panels
                on = x in (0, w - 1) or (y in (27,) and x % 6 != 0) or (x % 12 == 6 and y > 25)
            row.append('#' if on else '.')
        rows.append(''.join(row))
    return rows


def rows(art):
    rs = art.split()
    assert len(rs) == 8 and all(len(r) == 8 for r in rs), art
    return [int(r.replace('#', '1').replace('.', '0'), 2) for r in rs]


def dome_tiles():
    art = dome_art()
    out = {}
    for r in range(DOME_H):
        for c in range(DOME_W):
            cell = ' '.join(art[r * 8 + y][c * 8:c * 8 + 8] for y in range(8))
            out[f'DOME_{r}{c}'] = (DOME_COLOR, cell)
    return out


def main():
    GEN.mkdir(exist_ok=True)
    codes = {}
    glyphs = {}
    colors = [FONT_COLOR] * 256
    passable = list(PASSABLE.items()) + [(n, (FONT_COLOR, a)) for n, a in UI.items()]
    blocked = list(BLOCKED.items()) + list(dome_tiles().items())
    assert len(passable) <= BLOCK_BASE - TILE_FIRST, f'{len(passable)} passable codes > 64'
    assert len(blocked) <= 256 - BLOCK_BASE, f'{len(blocked)} blocked codes > 128'
    for base, table in ((TILE_FIRST, passable), (BLOCK_BASE, blocked)):
        for i, (name, (col, art)) in enumerate(table):
            code = base + i
            codes[name] = code
            glyphs[code] = rows(art)
            colors[code] = col
    last = max(glyphs)
    assert last <= 0xff
    blob = bytearray()
    for code in range(TILE_FIRST, last + 1):
        blob += bytes(glyphs.get(code, [0] * 8))
    (GEN / 'tiles.bin').write_bytes(bytes(blob))
    (GEN / 'tilecolors.bin').write_bytes(bytes(colors))
    inc = ['; generated by tools/make_tiles.py - do not edit',
           f'TILE_FIRST = ${TILE_FIRST:02x}', f'BLOCK_BASE = ${BLOCK_BASE:02x}',
           f'TILE_LAST = ${last:02x}', 'T_BLANK = $20']
    inc += [f'{"G" if n in UI else "T"}_{n} = ${c:02x}' for n, c in codes.items()]
    (GEN / 'tiles.inc').write_text('\n'.join(inc) + '\n')
    codes['_n_passable'] = len(passable)
    codes['_n_blocked'] = len(blocked)
    return codes


if __name__ == '__main__':
    c = main()
    print(f'{c["_n_passable"]} passable, {c["_n_blocked"]} blocked codes')
    print('\n'.join(dome_art()))
