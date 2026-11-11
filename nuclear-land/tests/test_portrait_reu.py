"""With an REU, a face read from disk is kept there (talk.asm portrait_load), so only the first visit
to each person reads the disk. Hesper, then Brandt, then Hesper again: with an REU the disk is read
twice and the third visit's portrait (fetched by DMA) is pixel-exact; without one, three reads."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_portrait  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

REU = ['-reu', '-reusize', '512']
AT = 5_009_500 + 2200 * vice.CYCLES_PER_FRAME     # the third talk is open


def main():
    set_palette(vice.palette())
    prg = vice.build({'AUTOWALK': 28, 'TYPESCRIPT': 10})
    lab = vice.labels(prg)
    for extra, reu in ((REU, True), ((), False)):
        what = 'REU' if reu else 'no REU'
        present, loads, cached, person, mode = vice.memread(
            prg, lab['reu_present'], 1, wait_s=14.0, extra=extra, extra_reads=[
                (14.0, lab['face_disk_loads'], 1), (14.0, lab['face_cached'], 1),
                (14.0, lab['talk_person'], 1), (14.0, lab['game_mode'], 1)])
        vice.check(mode[0] == 1 and person[0] == 0, f'{what}: third talk is with Hesper (mode {mode[0]}, cast {person[0]})')
        vice.check(present[0] == (1 if reu else 0), f'{what}: reu_present = {present[0]}')
        vice.check(loads[0] == (2 if reu else 3), f'{what}: {loads[0]} faces read from disk')
        vice.check(cached[0] == (0b11 if reu else 0), f'{what}: cached faces {cached[0]:#010b}')
    want = make_portrait.render((vice.NL / 'gen' / 'portrait_hesper.bin').read_bytes())
    for (x, y), c in make_portrait.render_eyes((vice.NL / 'gen' / 'eyes_hesper.bin').read_bytes()).items():
        want[y][x] = c
    shot = vice.screenshot(prg, AT, extra=REU)
    shot.save(vice.BUILD / 'portrait_reu.png')
    x0, y0 = vice.screen_box(shot)
    got = [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(152)]
    vice.check(got == want, "REU: Hesper's portrait and eye sprites fetched back pixel-exact")


if __name__ == '__main__':
    main()
