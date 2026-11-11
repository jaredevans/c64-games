"""assets/<name>_c64_128x152.png -> gen/portrait_<name>.bin: a 16x19-cell C64 hi-res portrait.

Input: 128x152 px. Every pixel maps to the nearest C64 (Pepto) colour; each 8x8 cell keeps its two
most frequent colours (other pixels take the nearer of the two). Black, when kept, is the background.
Output (2736 bytes): 2432 bitmap bytes in cell order (row 0..18, column 0..15, 8 bytes per cell, top
pixel row first, bit 7 = leftmost pixel = foreground), then 304 colour bytes, one per cell,
(fg << 4) | bg - the hi-res bitmap's screen-RAM format.

Usage: python3 tools/make_portrait.py hesper warden"""
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
from c64render import PALETTE, nearest_index  # noqa: E402

W, H = 128, 152
COLS, ROWS = W // 8, H // 8


def _dist(a, b):
    return sum((u - v) ** 2 for u, v in zip(PALETTE[a], PALETTE[b]))


def convert(png_path, out_path):
    im = Image.open(png_path).convert('RGB')
    if im.size != (W, H):
        raise ValueError(f'{png_path}: {im.size[0]}x{im.size[1]}, portraits must be {W}x{H}')
    bitmap, colours, reduced = bytearray(), bytearray(), 0
    for r in range(ROWS):
        for c in range(COLS):
            cell = [[nearest_index(im.getpixel((c * 8 + x, r * 8 + y))) for x in range(8)] for y in range(8)]
            count = Counter(i for row in cell for i in row)
            if len(count) > 2:
                reduced += 1
            kept = [i for i, _ in count.most_common(2)]
            if len(kept) == 1:
                bg, fg = kept[0], 0                 # one colour: all background
            elif 0 in kept:
                bg, fg = 0, sum(kept)               # black (0) is the background
            else:
                fg, bg = kept
            for row in cell:
                byte = 0
                for x, i in enumerate(row):
                    if i not in (fg, bg):
                        i = fg if _dist(i, fg) < _dist(i, bg) else bg
                    if i == fg and fg != bg:
                        byte |= 0x80 >> x
                bitmap.append(byte)
            colours.append(fg << 4 | bg)
    Path(out_path).write_bytes(bytes(bitmap + colours))
    return {'cells_reduced': reduced}


def render(data):
    """152 x 128 grid of palette indices, as the VIC shows the converted portrait."""
    out = [[0] * W for _ in range(H)]
    for r in range(ROWS):
        for c in range(COLS):
            n = r * COLS + c
            col = data[ROWS * COLS * 8 + n]
            fg, bg = col >> 4, col & 15
            for y in range(8):
                byte = data[n * 8 + y]
                for x in range(8):
                    out[r * 8 + y][c * 8 + x] = fg if byte & (0x80 >> x) else bg
    return out


if __name__ == '__main__':
    for name in sys.argv[1:]:
        info = convert(NL / 'assets' / f'{name}_c64_128x152.png', NL / 'gen' / f'portrait_{name}.bin')
        print(f'{name}: {info["cells_reduced"]} cells reduced to 2 colours')
