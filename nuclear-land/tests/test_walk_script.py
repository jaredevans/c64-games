"""Task 3: a scripted walk (incl. a wall bump and a mid-glide release) ends exactly on the tile grid
at the expected camera, with the HUD untouched."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets, render_view  # noqa: E402
from walksim import simulate  # noqa: E402

UP, DOWN, LEFT, RIGHT = 0, 1, 2, 3
G = 8
# must match the AUTOWALK=1 script in input.asm
SCRIPT = [(5 * G, RIGHT), (3 * G, UP), (3, DOWN), (10, None), (2 * G, LEFT), (1, None)]
SPRITE_BOX = (19 * 8, 11 * 8 - 8, 32, 24)


def main():
    mp, glyph, colors = load_assets('testmap')
    want = simulate(SCRIPT, mp)
    vice.check(want['steps'] == 10 and want['bumps'] >= 1, f'model agrees with the plan: {want}')
    ref = vice.screenshot(vice.build({'TESTMAP': 1}), 5_000_000)
    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 1})
    lab = vice.labels(prg)
    total = sum(n for n, _ in SCRIPT) + 100
    shot = vice.screenshot(prg, 5_000_000 + total * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'walk_script.png')
    exp = render_view(mp, glyph, colors, *want['cam'])
    dx, dy = vice.rest_shift(lab)
    mis = vice.band_mismatch(shot, exp, ignore_box=SPRITE_BOX, dx=dx, dy=dy)
    vice.check(mis <= 0.01, f'map band matches camera {want["cam"]} (mismatch {mis:.3%})')
    vice.check(vice.band_pixels(shot, (21, 25)) == vice.band_pixels(ref, (21, 25)), 'HUD unchanged')
    mem = vice.memread(prg, lab['steps_done'], 3, wait_s=6.0)
    steps, bumps = mem[0] | mem[1] << 8, mem[2]
    vice.check(steps == want['steps'], f'steps_done {steps} == {want["steps"]}')
    vice.check(bumps >= 1, f'bumps {bumps} >= 1')
    leader = vice.memread(prg, lab['leader_x'], 2, wait_s=6.0)
    vice.check(tuple(leader) == want['leader'], f'leader {tuple(leader)} == {want["leader"]}')


if __name__ == '__main__':
    main()
