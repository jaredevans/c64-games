"""Task 1: the first view shows the test map at the start camera, with status + HUD text."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets, render_view  # noqa: E402

SPRITE_BOX = (19 * 8, 11 * 8 - 8, 32, 24)   # leader sprite over band cell (19,9) = screen cell (19,11)


def main():
    prg = vice.build({'TESTMAP': 1})
    lab = vice.labels(prg)
    shot = vice.screenshot(prg, 4_000_000)
    mp, glyph, colors = load_assets('testmap')
    exp = render_view(mp, glyph, colors, lab['MAP_START_X'] - 19, lab['MAP_START_Y'] - 9)
    dx, dy = vice.rest_shift(lab)
    mis = vice.band_mismatch(shot, exp, ignore_box=SPRITE_BOX, dx=dx, dy=dy)
    vice.check(mis <= 0.01, f'map band matches start view (mismatch {mis:.3%})')
    vice.check(vice.has_ink(shot, (0, 1)), 'status row 0 has text')
    vice.check(vice.has_ink(shot, (21, 25)), 'HUD rows 21-24 have text')
    shot.save(vice.BUILD / 'static_view.png')


if __name__ == '__main__':
    main()
