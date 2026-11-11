"""Portraits load from disk (talk.asm portrait_load). The other talk tests use VICE's KERNAL traps,
where a load is instant; here a real 1541 is emulated (its own CPU and the serial bus, whose KERNAL
routines re-enable IRQs), and the portrait must arrive intact, with "you approach hesper..." on
the screen meanwhile. Also: with no drive the talking screen still opens, with a black portrait
and no eye sprites."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_portrait  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

F = vice.CYCLES_PER_FRAME
LGREY = 15
AT = 5_009_500 + 700 * F             # test_talk_screen.py: talking screen open (instant load)


def pixels(shot):
    x0, y0 = vice.screen_box(shot)
    return [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(320)] for y in range(200)]


def first_frame(prg, want, truedrive, lo=0, hi=3000):
    """First frame (after 5_009_500 cycles, within 2) with the portrait on screen."""
    def ok(n):
        shot = vice.screenshot(prg, 5_009_500 + n * F, truedrive=truedrive)
        return [row[:128] for row in pixels(shot)[:152]] == want
    if not ok(hi):
        return None
    while hi - lo > 2:
        m = (lo + hi) // 2
        if ok(m):
            hi = m
        else:
            lo = m
    return hi


def main():
    set_palette(vice.palette())
    want = make_portrait.render((vice.NL / 'gen' / 'portrait_hesper.bin').read_bytes())
    for (x, y), c in make_portrait.render_eyes((vice.NL / 'gen' / 'eyes_hesper.bin').read_bytes()).items():
        want[y][x] = c
    prg = vice.build({'AUTOWALK': 18})
    fast = first_frame(prg, want, truedrive=False)
    slow = first_frame(prg, want, truedrive=True, lo=fast or 0)
    vice.check(slow is not None, "real 1541: Hesper's portrait and eye sprites arrive pixel-exact")
    if fast and slow:
        print(f'   (a stock 1541 takes about {(slow - fast) / 50:.1f} s to load a portrait)')
        # while it loads: "you approach hesper..." on row 11 of an otherwise empty text screen
        charset = vice.memread(prg, 0xc800, 512, wait_s=3.0)            # the walking charset
        line = vice.scr('        YOU APPROACH HESPER...'.ljust(40))
        want_screen = [[0] * 320 for _ in range(200)]
        for y in range(8):
            for c, code in enumerate(line):
                for x in range(8):
                    if charset[code * 8 + y] & (0x80 >> x):
                        want_screen[11 * 8 + y][c * 8 + x] = LGREY
        mid = (fast + slow) // 2
        shot = vice.screenshot(prg, 5_009_500 + mid * F, truedrive=True)
        shot.save(vice.BUILD / 'portrait_loading.png')
        vice.check(pixels(shot) == want_screen, 'while loading: "you approach hesper..." alone on the screen')

    shown = pixels(vice.screenshot(prg, AT))
    blank = pixels(vice.screenshot(prg, AT, disk=False))
    vice.check(all(c == 0 for row in blank[:152] for c in row[:128]), 'no drive: black portrait, no eye sprites')
    rest = all(b == s for y in range(200) for x, (b, s) in enumerate(zip(blank[y], shown[y]))
               if not (x < 128 and y < 152))
    vice.check(rest, 'no drive: the rest of the talking screen exactly as with the portrait loaded')


if __name__ == '__main__':
    main()
