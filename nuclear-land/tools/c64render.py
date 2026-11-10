"""Reference renderer: map bytes + tiles -> expected colour-index image of the map view."""
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
GEN = NL / 'gen'

# Pepto PAL palette (close to VICE's defaults; tests match by nearest colour).
PALETTE = [(0x00, 0x00, 0x00), (0xff, 0xff, 0xff), (0x68, 0x37, 0x2b), (0x70, 0xa4, 0xb2),
           (0x6f, 0x3d, 0x86), (0x58, 0x8d, 0x43), (0x35, 0x28, 0x79), (0xb8, 0xc7, 0x6f),
           (0x6f, 0x4f, 0x25), (0x43, 0x39, 0x00), (0x9a, 0x67, 0x59), (0x44, 0x44, 0x44),
           (0x6c, 0x6c, 0x6c), (0x9a, 0xd2, 0x84), (0x6c, 0x5e, 0xb5), (0x95, 0x95, 0x95)]
_cache = {}


def set_palette(pal):
    """Use a measured palette (e.g. vice.palette()) for nearest-colour matching."""
    PALETTE[:] = [tuple(c) for c in pal]
    _cache.clear()


def nearest_index(rgb):
    if rgb not in _cache:
        _cache[rgb] = min(range(16), key=lambda i: sum((a - b) ** 2 for a, b in zip(PALETTE[i], rgb)))
    return _cache[rgb]


def load_assets():
    """Returns (map_bytes, glyph_for_code, colors). glyph_for_code(code) -> 8 row bytes or None
    for ROM font codes (not rendered; map views never contain them)."""
    inc = (GEN / 'tiles.inc').read_text()
    first = int([l for l in inc.splitlines() if l.startswith('TILE_FIRST')][0].split('=')[1].strip().lstrip('$'), 16)
    tiles = (GEN / 'tiles.bin').read_bytes()
    colors = (GEN / 'tilecolors.bin').read_bytes()
    mp = (GEN / 'testmap.bin').read_bytes()

    def glyph(code):
        if code == 32:
            return [0] * 8
        if code < first:
            return None
        off = (code - first) * 8
        return list(tiles[off:off + 8])
    return mp, glyph, colors


def render_view(map_bytes, glyph, colors, cam_x, cam_y, cols=40, rows=18, map_w=64, bg=0):
    """2-D list [y][x] of colour indices for a cols x rows cell view whose top-left is (cam_x, cam_y)."""
    out = [[bg] * (cols * 8) for _ in range(rows * 8)]
    for r in range(rows):
        for c in range(cols):
            code = map_bytes[(cam_y + r) * map_w + cam_x + c]
            g = glyph(code)
            if g is None:
                raise ValueError(f'font code {code} in map view')
            for yy in range(8):
                for xx in range(8):
                    if g[yy] >> (7 - xx) & 1:
                        out[r * 8 + yy][c * 8 + xx] = colors[code] & 15
    return out
