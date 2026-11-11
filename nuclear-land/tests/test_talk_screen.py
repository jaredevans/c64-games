"""M3 Task 3 / Review Focus 4: T next to Hesper opens the talking screen - her portrait pixel-exact in
the top-left 16x19 cells (hi-res bitmap), the text rows below - and the bitmap/text boundary (screen
row 18 -> 19) is exact and steady on every frame."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_portrait  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

LGREY = 15
AT = 5_009_500 + 700 * vice.CYCLES_PER_FRAME     # well after T; stops below the display


def text_row_pixels(charset, text, colour):
    """8 x 320 colour indices of one text row rendered with the walking charset (codes 0-63)."""
    codes = vice.scr(text.ljust(40))
    return [[colour if charset[c * 8 + y] & (0x80 >> x) else 0 for c in codes for x in range(8)] for y in range(8)]


def main():
    set_palette(vice.palette())
    prg = vice.build({'AUTOWALK': 18})
    lab = vice.labels(prg)
    mode, rows, charset = vice.memread(prg, lab['game_mode'], 1, wait_s=6.0, extra_reads=[
        (6.0, 0xc400 + 19 * 40, 200), (6.0, 0xc800, 512)])
    vice.check(mode[0] == 1, f'talking screen open (game_mode {mode[0]})')
    vice.check(rows[80:120].startswith(vice.scr('DIALS LEADS. ASK ABOUT:')), f'row 21: {rows[80:120]!r}')
    vice.check(rows[120:122] == vice.scr('> '), f'row 22 prompt: {rows[120:122]!r}')
    portrait = make_portrait.render((vice.NL / 'gen' / 'portrait_hesper.bin').read_bytes())
    shot = vice.screenshot(prg, AT)
    shot.save(vice.BUILD / 'talk_screen.png')
    x0, y0 = vice.screen_box(shot)
    got = [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(152)]
    vice.check(got == portrait, "Hesper's portrait pixel-exact in the top-left 16x19 cells")
    known = text_row_pixels(charset, 'KNOWN: NAME JOB REACTOR VOSS', LGREY)
    bad = 0
    for k in range(16):
        s = vice.screenshot(prg, AT + k * vice.CYCLES_PER_FRAME)
        x0, y0 = vice.screen_box(s)
        last = [[nearest_index(s.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(144, 152)]
        txt = [[nearest_index(s.getpixel((x0 + x, y0 + y))) for x in range(320)] for y in range(152, 160)]
        if last != portrait[144:152] or txt != known:
            bad += 1
            s.save(vice.BUILD / f'talk_boundary_bad{k}.png')
    vice.check(bad == 0, f'bitmap row 18 / text row 19 boundary exact in 16 consecutive frames ({bad} bad)')


if __name__ == '__main__':
    main()
