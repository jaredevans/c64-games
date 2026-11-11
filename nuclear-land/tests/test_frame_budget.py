"""M2 Task 4 / Review Focus 3: the main loop places every sprite before the top split at raster 62
(so sprites never tear), and a flip frame's colour copy also ends before it (so the map's colours
never lag the characters for a frame)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402


def main():
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 4, 'TIMING': 1})
    lab = vice.labels(prg)
    m = vice.memread(prg, lab['late_max'], 2, wait_s=10.0)
    late = m[0] | m[1] << 8
    vice.check(late > 0, f'measured ({late})')
    vice.check(late < 312 + 62, f'latest sprite placement on raster {late} (wrapped) < {312 + 62}')
    m = vice.memread(prg, lab['colour_max'], 2, wait_s=10.0)
    col = m[0] | m[1] << 8
    vice.check(col > 0, f'colour copy measured ({col})')
    vice.check(col < 312 + 62, f'flip-frame colour copy done by raster {col} (wrapped) < {312 + 62}')


if __name__ == '__main__':
    main()
