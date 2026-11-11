"""M2 Task 4: Pip wanders Market Row - inside his box, only on passable non-hot tiles, never onto
another person or the (idle) leader."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets  # noqa: E402

PIP = 5


def main():
    meta = json.loads((vice.NL / 'gen' / 'cinderhill.json').read_text())
    mp, _, _ = load_assets('cinderhill')
    hot = {tuple(h) for h in meta['hot']}
    bx0, by0, bx1, by1 = meta['people'][PIP]['box']
    prg = vice.build()
    lab = vice.labels(prg)
    reads = [(t, lab['people_x'], 14) for t in (5.0, 7.0, 9.0, 11.0, 13.0)]
    samples = vice.memread(prg, lab['people_x'], 14, wait_s=3.0, extra_reads=reads)
    seen = set()
    for s in samples:
        xs, ys = s[:7], s[7:]
        pip = (xs[PIP], ys[PIP])
        others = {(xs[i], ys[i]) for i in range(7) if i != PIP}
        ok = bx0 <= pip[0] <= bx1 and by0 <= pip[1] <= by1 and mp[pip[1] * 64 + pip[0]] < 0x80 and \
            pip not in hot and pip not in others and pip != tuple(meta['start'])
        vice.check(ok, f'Pip at {pip}: in his box, on open ground, alone')
        vice.check(all(others_i == (p['x'], p['y']) for others_i, p in
                       zip([(xs[i], ys[i]) for i in range(7) if i != PIP],
                           [p for i, p in enumerate(meta['people']) if i != PIP])),
                   'everyone else stands still')
        seen.add(pip)
    vice.check(len(seen) >= 3, f'Pip visited {len(seen)} cells')


if __name__ == '__main__':
    main()
