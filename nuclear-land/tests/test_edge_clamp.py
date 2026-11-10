"""Task 4: at the map's west edge the camera clamps at 0 and the leader sprite walks instead."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets, render_view  # noqa: E402
from walksim import simulate  # noqa: E402

LEFT = 2
SCRIPT = [(240, LEFT), (1, None)]        # must match the AUTOWALK=3 script in input.asm


def main():
    mp, glyph, colors = load_assets()
    want = simulate(SCRIPT, mp)
    vice.check(want['leader'] == (1, 19) and want['cam'] == (0, 10) and want['bumps'] >= 1,
               f'model: {want}')
    prg = vice.build({'AUTOWALK': 3})
    lab = vice.labels(prg)
    shot = vice.screenshot(prg, 5_000_000 + 400 * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'edge_clamp.png')
    col = want['leader'][0] - want['cam'][0]          # leader's band column (1)
    box = (col * 8, 11 * 8 - 8, 32, 24)
    dx, dy = vice.rest_shift(lab)
    exp = render_view(mp, glyph, colors, *want['cam'])
    mis = vice.band_mismatch(shot, exp, ignore_box=box, dx=dx, dy=dy)
    vice.check(mis <= 0.01, f'map band matches clamped camera {want["cam"]} (mismatch {mis:.3%})')
    x0, y0 = vice.screen_box(shot)
    white = sum(1 for x in range(box[0], box[0] + box[2]) for y in range(box[1], box[1] + box[3])
                if shot.getpixel((x0 + x, y0 + y)) == (255, 255, 255))
    vice.check(white >= 20, f'leader sprite drawn at band column {col} ({white} white px)')
    m = vice.memread(prg, lab['leader_x'], 1, wait_s=8.0)
    c = vice.memread(prg, lab['cam_x'], 1, wait_s=8.0)
    vice.check(m[0] == 1 and c[0] == 0, f'leader_x {m[0]} == 1, cam_x {c[0]} == 0')


if __name__ == '__main__':
    main()
