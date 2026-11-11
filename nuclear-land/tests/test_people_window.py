"""M2 Task 4 / Review Focus 1: townspeople crossing the map window's top and bottom edges during
vertical glides never put a pixel on the status row, the blank rows around the map, or the HUD, and
both people really do appear and disappear across the run."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

LRED, GREEN = 10, 5
BLACK_ROWS = list(range(8, 23)) + list(range(160, 168))


def main():
    set_palette(vice.palette())
    ref = vice.screenshot(vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1}), 5_000_000)
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 9})
    bad = 0
    seen = {LRED: set(), GREEN: set()}
    for k in range(64):
        s = vice.screenshot(prg, 5_000_000 + k * vice.CYCLES_PER_FRAME)
        x0, y0 = vice.screen_box(s)
        px = s.load()
        strips = s.crop((x0, y0, x0 + 320, y0 + 8)).tobytes() == ref.crop((x0, y0, x0 + 320, y0 + 8)).tobytes() and \
            s.crop((x0, y0 + 168, x0 + 320, y0 + 200)).tobytes() == ref.crop((x0, y0 + 168, x0 + 320, y0 + 200)).tobytes()
        black = all(px[x0 + x, y0 + y] == (0, 0, 0) for y in BLACK_ROWS for x in range(8, 311))  # 38-col border
        if not (strips and black):
            bad += 1
            s.save(vice.BUILD / f'people_window_bad{k}.png')
        band = {nearest_index(px[x0 + x, y0 + y]) for y in range(23, 160) for x in range(8, 311)}
        for c in seen:
            seen[c].add(c in band)
    vice.check(bad == 0, f'status, HUD and the rows around the map clean in all 64 frames ({bad} bad)')
    vice.check(seen[LRED] == {True, False}, 'P2 (top edge) seen both shown and hidden')
    vice.check(seen[GREEN] == {True, False}, 'P3 (bottom edge) seen both shown and hidden')


if __name__ == '__main__':
    main()
