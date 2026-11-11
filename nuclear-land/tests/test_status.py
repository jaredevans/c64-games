"""M2 Task 3: the status line (row 0, both screen buffers) names the leader's place and shows the
Geiger meter: 8 cells, rad level (0..8) of them lit."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402


def expect(lab, place, rad):
    return vice.scr(f'CINDERHILL - {place}'.ljust(27) + ' RAD ') + \
        bytes([lab['G_METER_ON']] * rad + [lab['G_METER_OFF']] * (8 - rad))


def both_rows(prg, row, wait_s):
    a, b = vice.memread(prg, 0xc000 + row * 40, 40, wait_s=wait_s, extra_reads=[(wait_s, 0xc400 + row * 40, 40)])
    return a, b


def main():
    prg = vice.build()
    lab = vice.labels(prg)
    a, b = both_rows(prg, 0, 4.0)
    want = expect(lab, 'TOWN SQUARE', 0)
    vice.check(a == want and b == want, f'Cinderhill start: row 0 = {a!r}')

    prg = vice.build({'TESTMAP': 1})     # start (29,19) is outside WEST SIDE (x <= 19): the place
    lab = vice.labels(prg)                # lookup must use the real start, not the cell (0,0)
    a, b = both_rows(prg, 0, 4.0)
    want = expect(lab, 'TEST MAP', 0)
    vice.check(a == want and b == want, f'test map start (29,19): row 0 = {a!r}')

    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 7})
    lab = vice.labels(prg)
    a, b = both_rows(prg, 0, 6.0)
    want = expect(lab, 'WEST SIDE', 6)
    vice.check(a == want and b == want, f'test map (10,20), next to a hot spot: row 0 = {a!r}')


if __name__ == '__main__':
    main()
