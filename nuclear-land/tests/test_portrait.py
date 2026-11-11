"""M3 Task 1: the PNG -> C64 hi-res portrait converter (128x152 px = 16x19 cells, 2 colours per cell)."""
import sys
import tempfile
from pathlib import Path

from PIL import Image

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_portrait  # noqa: E402
from c64render import PALETTE, nearest_index  # noqa: E402
from vice import check  # noqa: E402

WHITE, RED, BLUE = 1, 2, 6


def main():
    for name in ('hesper', 'Ilse-Brandt', 'Tamsin-Reyes', 'Jory-Platt', 'Odalys-Finch', 'Pip', 'Silas-Corwin', 'Abel-Voss'):
        out = NL / 'gen' / f'portrait_{name}.bin'
        src = NL / 'assets' / f'{name}_c64_128x152.png'
        info = make_portrait.convert(src, out)
        data = out.read_bytes()
        check(len(data) == 2736, f'{name}: 2432 bitmap + 304 colour bytes ({len(data)})')
        check(info['cells_reduced'] == 0, f'{name}: already C64-legal, no cell reduced')
        im = Image.open(src).convert('RGB')
        want = [[nearest_index(im.getpixel((x, y))) for x in range(128)] for y in range(152)]
        check(make_portrait.render(data) == want, f'{name}: converted portrait renders pixel-exact')
        eyes_png = NL / 'assets' / f'{name}_eyes_128x152.png'
        eyes_out = NL / 'gen' / f'eyes_{name}.bin'
        n = make_portrait.convert_eyes(eyes_png, eyes_out)
        check(1 <= n <= make_portrait.EYE_SPRITES, f'{name}: {n} eye sprites (1-{make_portrait.EYE_SPRITES})')
        em = Image.open(eyes_png).convert('RGB')
        want_eyes = {(x, y): i for y in range(152) for x in range(128) if (i := nearest_index(em.getpixel((x, y))))}
        check(make_portrait.render_eyes(eyes_out.read_bytes()) == want_eyes, f'{name}: eye sprites draw the eyes layer exactly')

    with tempfile.TemporaryDirectory() as td:
        im = Image.new('RGB', (128, 152), PALETTE[0])
        px = [(x, y) for y in range(8) for x in range(8)]
        for i, (x, y) in enumerate(px):          # cell (0,0): 40 white, 20 red, 4 blue
            im.putpixel((x, y), PALETTE[WHITE if i < 40 else RED if i < 60 else BLUE])
        p = Path(td) / 'three.png'
        im.save(p)
        info = make_portrait.convert(p, Path(td) / 'three.bin')
        check(info['cells_reduced'] == 1, 'a 3-colour cell is reduced')
        got = make_portrait.render((Path(td) / 'three.bin').read_bytes())
        d = lambda a, b: sum((u - v) ** 2 for u, v in zip(PALETTE[a], PALETTE[b]))
        nearer = WHITE if d(BLUE, WHITE) <= d(BLUE, RED) else RED
        check(all(got[y][x] == nearer for i, (x, y) in enumerate(px) if i >= 60) and
              all(got[y][x] == WHITE for i, (x, y) in enumerate(px) if i < 40),
              f'kept white/red; blue pixels became the nearer one ({nearer})')
        Image.new('RGB', (64, 64)).save(Path(td) / 'small.png')
        try:
            make_portrait.convert(Path(td) / 'small.png', Path(td) / 'x.bin')
            check(False, 'a 64x64 image is rejected')
        except ValueError:
            check(True, 'a 64x64 image is rejected')


if __name__ == '__main__':
    main()
