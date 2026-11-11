"""M2 Task 2 / Review Focus 5: at the north and south map edges the camera clamps and the leader
sprite walks instead; the figure stays whole inside the map window, the top/bottom gap rows stay black
in every glide phase, and the status line and HUD are untouched."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets, render_view  # noqa: E402
from walksim import simulate  # noqa: E402

UP, DOWN, RIGHT = 0, 1, 3
NORTH = [(144, UP), (1, None)]                       # must match AUTOWALK=11 in input.asm
SOUTH = [(88, RIGHT), (216, DOWN), (1, None)]        # must match AUTOWALK=12
GAP = list(range(16, 23)) + list(range(160, 168))    # display rows just outside the map window
TM = {'TESTMAP': 1}


def gap_black(shot):
    x0, y0 = vice.screen_box(shot)
    return all(shot.getpixel((x0 + x, y0 + y)) == (0, 0, 0) for y in GAP for x in range(8, 311))


def scenario(name, script, autowalk, leader, cam_y, ref, mp, glyph, colors):
    want = simulate(script, mp)
    vice.check(want['leader'] == leader and want['cam'][1] == cam_y and want['bumps'] >= 1, f'{name} model: {want}')
    prg = vice.build({**TM, 'AUTOWALK': autowalk})
    lab = vice.labels(prg)
    walk = sum(n for n, _ in script)
    end = vice.screenshot(prg, 5_000_000 + (walk + 60) * vice.CYCLES_PER_FRAME)
    end.save(vice.BUILD / f'edge_clamp_{name}.png')
    col, row = want['leader'][0] - want['cam'][0], want['leader'][1] - want['cam'][1]
    box = (col * 8, (row + 2) * 8 - 8, 32, 24)
    dx, dy = vice.rest_shift(lab)
    exp = render_view(mp, glyph, colors, *want['cam'])
    mis = vice.band_mismatch(end, exp, ignore_box=box, dx=dx, dy=dy)
    vice.check(mis <= 0.01, f'{name}: map band matches clamped camera {want["cam"]} (mismatch {mis:.3%})')
    x0, y0 = vice.screen_box(end)
    white = sum(1 for x in range(box[0], box[0] + box[2]) for y in range(box[1], box[1] + box[3])
                if end.getpixel((x0 + x, y0 + y)) == (255, 255, 255))
    vice.check(white >= 45, f'{name}: whole leader sprite visible at band row {row} ({white} white px)')
    # 24 frames from just before the script starts (~90 frames before the 5M-cycle mark), an odd
    # stride apart so they span the whole walk and hit every glide phase
    stride = (walk + 40) // 24 | 1
    bad = seen = 0
    for k in range(24):
        s = vice.screenshot(prg, 5_000_000 + (k * stride - 100) * vice.CYCLES_PER_FRAME)
        ok = gap_black(s) and vice.band_pixels(s, (0, 1)) == vice.band_pixels(ref, (0, 1)) and \
            vice.band_pixels(s, (21, 25)) == vice.band_pixels(ref, (21, 25))
        if not seen and not ok:
            continue                    # BASIC boot screen / game init before the IRQ chain runs
        seen += 1
        if not ok:
            bad += 1
            print(f'  bad frame {k * stride - 100:+d}')
            s.save(vice.BUILD / f'edge_clamp_{name}_bad{k}.png')
    vice.check(seen >= 20 and bad == 0,
               f'{name}: gap rows black, status + HUD untouched in {seen} frames across the walk ({bad} bad)')
    m = vice.memread(prg, lab['leader_x'], 2, wait_s=8.0)
    c = vice.memread(prg, lab['cam_x'], 2, wait_s=8.0)
    vice.check((tuple(m), tuple(c)) == (want['leader'], want['cam']),
               f'{name}: leader {tuple(m)}, cam {tuple(c)} == {want["leader"]}, {want["cam"]}')


def main():
    mp, glyph, colors = load_assets('testmap')
    ref = vice.screenshot(vice.build(TM), 5_000_000)
    scenario('north', NORTH, 11, (29, 2), 0, ref, mp, glyph, colors)
    scenario('south', SOUTH, 12, (40, 45), 30, ref, mp, glyph, colors)


if __name__ == '__main__':
    main()
