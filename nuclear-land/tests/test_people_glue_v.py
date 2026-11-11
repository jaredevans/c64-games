"""M2 review fix: vertical glue - during vertical (FLD) glides, including the buffer flips at p=4/5, P1
(cyan, at (37,14)) keeps the same vertical distance to the bottom edge of the wall block beside it.

Captures stop at 5_009_500 + k frames: -limitcycles stops mid-frame, and at 5_000_000 the exit
screenshot's lower rows still show the previous frame, which would fake a 1-px wobble."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

CYAN, LGREY = 3, 15
BAND = range(23, 160)


def measure(shot):
    x0, y0 = vice.screen_box(shot)
    px = shot.load()
    cyan = [(x, y) for y in BAND for x in range(0, 320) if nearest_index(px[x0 + x, y0 + y]) == CYAN]
    if not cyan:
        return None
    left, bottom = min(x for x, _ in cyan), max(y for _, y in cyan)
    wall = [y for y in BAND for x in range(max(0, left - 40), left) if nearest_index(px[x0 + x, y0 + y]) == LGREY]
    return (bottom, bottom - max(wall)) if wall else None


def main():
    set_palette(vice.palette())
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 9})
    got = [measure(vice.screenshot(prg, 5_009_500 + k * vice.CYCLES_PER_FRAME)) for k in range(64)]
    got = [g for g in got if g]
    gaps = {g[1] for g in got}
    vice.check(len(got) >= 24, f'P1 and the wall measured in {len(got)} of 64 frames')
    vice.check(max(g[0] for g in got) - min(g[0] for g in got) >= 16, 'P1 moved vertically on screen')
    vice.check(len(gaps) == 1, f'P1 glued vertically: gap to the wall bottom always {sorted(gaps)} px')


if __name__ == '__main__':
    main()
