"""Review #4/#6: on every frame of real walking (all directions, flips, clamp) the status line and HUD
are untouched and the map band's top and bottom edges are fixed: the raster windows above and
below the visible map (display y 16-22 and 160-167) are always black."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

STATUS, HUD = (0, 1), (21, 25)
TOP_EDGE, BOTTOM_EDGE = range(16, 23), range(160, 168)   # display-window pixel rows
COLS = range(8, 311)                                      # inside the 38-column window (x=311 is border)


def black_rows(shot, rows):
    x0, y0 = vice.screen_box(shot)
    return all(shot.getpixel((x0 + x, y0 + y)) == (0, 0, 0) for y in rows for x in COLS)


def main():
    ref = vice.screenshot(vice.build({'TESTMAP': 1}), 5_000_000)
    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 4})       # 21x11 loop: right, down, left, up, forever
    base = 5_000_000 + 150 * vice.CYCLES_PER_FRAME
    bad_strip = bad_edge = 0
    n = 48
    for i in range(n):                       # 48 consecutive frames = 6 steps incl. flips
        shot = vice.screenshot(prg, base + i * vice.CYCLES_PER_FRAME)
        if vice.band_pixels(shot, HUD) != vice.band_pixels(ref, HUD) or \
                vice.band_pixels(shot, STATUS) != vice.band_pixels(ref, STATUS):
            bad_strip += 1
        if not (black_rows(shot, TOP_EDGE) and black_rows(shot, BOTTOM_EDGE)):
            bad_edge += 1
            if bad_edge == 1:
                shot.save(vice.BUILD / 'glide_edge_fail.png')
    vice.check(bad_strip == 0, f'status + HUD untouched on all {n} consecutive frames ({bad_strip} bad)')
    vice.check(bad_edge == 0, f'map band edges fixed (edge windows black) on all {n} frames ({bad_edge} bad)')


if __name__ == '__main__':
    main()
