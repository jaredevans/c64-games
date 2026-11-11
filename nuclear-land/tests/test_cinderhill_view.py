"""M2 Task 2: the plain build shows Cinderhill around the start cell (32,24), camera (13,15)."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets, render_view  # noqa: E402

SPRITE_BOX = (19 * 8, 11 * 8 - 8, 32, 24)   # leader over band cell (19,9) = screen cell (19,11)


def main():
    prg = vice.build()
    lab = vice.labels(prg)
    vice.check((lab['MAP_START_X'], lab['MAP_START_Y']) == (32, 24), 'start cell (32,24)')
    cam = (32 - 19, 24 - 9)
    shot = vice.screenshot(prg, 4_000_000)
    shot.save(vice.BUILD / 'cinderhill_view.png')
    mp, glyph, colors = load_assets('cinderhill')
    exp = render_view(mp, glyph, colors, *cam)
    dx, dy = vice.rest_shift(lab)
    mis = vice.band_mismatch(shot, exp, ignore_box=SPRITE_BOX, dx=dx, dy=dy)
    vice.check(mis <= 0.01, f'map band shows Cinderhill at camera {cam} (mismatch {mis:.3%})')
    people = json.loads((vice.NL / 'gen' / 'cinderhill.json').read_text())['people']
    for p in people:                     # anyone in view: their own box must not hide a mismatch
        c, r = p['x'] - cam[0], p['y'] - cam[1]
        if 0 <= c < 40 and 0 <= r < 18:
            m = vice.band_mismatch(shot, exp, ignore_box=(c * 8, (r + 2) * 8 - 8, 16, 24), dx=dx, dy=dy)
            vice.check(m <= 0.01, f'{p["name"]} in view at band ({c},{r}); band mismatch {m:.3%}')
    cell = vice.memread(prg, 0xc000 + (2 + 9) * 40 + 19, 1, wait_s=4.0)[0]
    vice.check(cell == mp[24 * 64 + 32], f'screen cell under the leader = map code ${cell:02x}')


if __name__ == '__main__':
    main()
