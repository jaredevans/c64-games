"""maps/<name>.txt (ASCII) -> gen/<name>.bin (one tile code per cell, row-major).

Legend: '.' ground (variant by position), '=' road, ':' rubble, '#' wall."""
import sys
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
import make_tiles  # noqa: E402


def convert(name, w=64, h=48):
    codes = make_tiles.main()
    lines = (NL / 'maps' / f'{name}.txt').read_text().splitlines()
    assert len(lines) == h, f'{name}: {len(lines)} rows, want {h}'
    out = bytearray()
    for y, line in enumerate(lines):
        assert len(line) == w, f'{name} row {y}: {len(line)} cols, want {w}'
        for x, ch in enumerate(line):
            if ch == '.':
                out.append(codes[f'GROUND{(x * 7 + y * 13) % 3}'])
            elif ch == '=':
                out.append(codes['ROAD'])
            elif ch == ':':
                out.append(codes['RUBBLE'])
            elif ch == '#':
                out.append(codes['WALL'])
            else:
                raise ValueError(f'{name} ({x},{y}): unknown {ch!r}')
    (NL / 'gen' / f'{name}.bin').write_bytes(bytes(out))


if __name__ == '__main__':
    convert(sys.argv[1] if len(sys.argv) > 1 else 'testmap')
