"""M2 Task 4 / Review Focus 2: a townsperson stays glued to the ground in every frame of a glide,
including buffer-flip frames: the gap between P1 (cyan, at (37,14)) and the wall block's right edge
just left of it never changes while the map scrolls under the walking leader."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

CYAN, LGREY = 3, 15
BAND = range(23, 160)            # visible map window, display rows


def measure(shot):
    x0, y0 = vice.screen_box(shot)
    px = shot.load()
    idx = {}
    cyan = [(x, y) for y in BAND for x in range(0, 320) if nearest_index(px[x0 + x, y0 + y]) == CYAN]
    if not cyan:
        return None
    left = min(x for x, _ in cyan)
    rows = {y for _, y in cyan}
    wall = [x for y in rows for x in range(0, left) if nearest_index(px[x0 + x, y0 + y]) == LGREY]
    return left, (left - max(wall)) if wall else None


def main():
    set_palette(vice.palette())
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 8})
    got = [measure(vice.screenshot(prg, 5_000_000 + k * vice.CYCLES_PER_FRAME)) for k in range(40)]
    vice.check(all(g and g[1] is not None for g in got), 'P1 and the wall beside it visible in all 40 frames')
    gaps = {g[1] for g in got}
    lefts = [g[0] for g in got]
    vice.check(max(lefts) - min(lefts) >= 16, f'P1 moved on screen ({min(lefts)}..{max(lefts)})')
    vice.check(len(gaps) == 1, f'P1 glued to the map: gap to the wall always {sorted(gaps)} px')


if __name__ == '__main__':
    main()
