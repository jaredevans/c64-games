"""M2 Task 4 / Review Focus 3: the main loop places every sprite before the top split at raster 62
(so sprites never tear), and a flip frame's colour copy also ends before it (so the map's colours
never lag the characters for a frame)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402


def budget(name, defines):
    prg = vice.build({**defines, 'AUTOWALK': 4, 'TIMING': 1})
    lab = vice.labels(prg)
    late_lo, late_hi, col_lo, col_hi = vice.memread(prg, lab['late_max'], 4, wait_s=10.0)
    late, col = late_lo | late_hi << 8, col_lo | col_hi << 8
    vice.check(late > 0 and col > 0, f'{name}: measured ({late}, {col})')
    vice.check(late < 312 + 62, f'{name}: latest sprite placement on raster {late} (wrapped) < {312 + 62}')
    vice.check(col < 312 + 62, f'{name}: flip-frame colour copy done by raster {col} (wrapped) < {312 + 62}')


def main():
    budget('test map, 3 people', {'TESTMAP': 1, 'TEST_PEOPLE': 1})
    budget('Cinderhill, 7 people', {})


if __name__ == '__main__':
    main()
