"""Every cast member's portrait and eye sprites on the talking screen, pixel-exact. Only Hesper has
dialogue built in, so the test talks to her with PORTRAIT_OF set: talk_enter then shows that cast
member's portrait (h b t j o p c v = 0-7; Hesper's own is test_talk_screen.py)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_portrait  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

CAST = ['hesper', 'Ilse-Brandt', 'Tamsin-Reyes', 'Jory-Platt', 'Odalys-Finch', 'Pip', 'Silas-Corwin', 'Abel-Voss']
AT = 5_009_500 + 700 * vice.CYCLES_PER_FRAME     # as test_talk_screen.py: well after T


def main():
    set_palette(vice.palette())
    for i, name in enumerate(CAST[1:], start=1):
        want = make_portrait.render((vice.NL / 'gen' / f'portrait_{name}.bin').read_bytes())
        for (x, y), c in make_portrait.render_eyes((vice.NL / 'gen' / f'eyes_{name}.bin').read_bytes()).items():
            want[y][x] = c
        prg = vice.build({'AUTOWALK': 18, 'PORTRAIT_OF': i})
        shot = vice.screenshot(prg, AT)
        shot.save(vice.BUILD / f'portrait_{name}.png')
        x0, y0 = vice.screen_box(shot)
        got = [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(152)]
        bad = sum(g != w for gr, wr in zip(got, want) for g, w in zip(gr, wr))
        vice.check(bad == 0, f'{name}: portrait and eye sprites pixel-exact on the talking screen ({bad} px off)')


if __name__ == '__main__':
    main()
